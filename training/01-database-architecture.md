# Module 01 — Database Architecture: How Cassandra Works

Understanding how Cassandra works internally helps you operate, troubleshoot, and tune the cluster effectively. This module covers the core mechanisms that make Cassandra a distributed, highly available database.

📌 **No cluster required:** This module is concepts only. You will run the related commands (e.g. `nodetool gossipinfo`, `nodetool compactionstats`) in later modules once the cluster is up ([03 – Environment](03-environment.md) and [05 – Monitoring](05-monitoring.md)).

📚 **Reference**: This module is based on the [DSE 6.8 Database Architecture documentation](https://docs.datastax.com/en/dse/6.8/architecture/database-architecture/database-architecture-contents.html) and [DSE 6.9 Database Architecture documentation](https://docs.datastax.com/en/dse/6.9/architecture/database-architecture/database-architecture-contents.html).

## 🎯 Goals

- 🔍 Understand how nodes communicate via gossip
- 📊 Explain how data is distributed and replicated
- 💾 Describe the write and read paths
- 🔧 Understand compaction and repair mechanisms
- ⚙️ Relate these concepts to operational tasks

## 🔗 Internode Communications: Gossip

Cassandra uses a **gossip protocol** for peer-to-peer communication. Each node periodically exchanges state information with a few other nodes (typically 3), propagating updates throughout the cluster.

**What gossip carries:**
- Node status (UP, DOWN, JOINING, LEAVING)
- Token ranges (which nodes own which data)
- Datacenter and rack information
- Load information (for dynamic snitching)

**Why it matters:**
- ✅ No single point of failure: nodes discover each other without a central coordinator
- ⚡ Fast failure detection: nodes learn about failures within seconds
- 🔄 Automatic topology discovery: new nodes learn the cluster layout from seeds

💡 **In the lab (once the cluster is up)**: When `dse-node-1` starts, it contacts `dse-seed` (via `SEEDS=dse-seed`), learns about the cluster through gossip, and joins the ring. You will inspect gossip in [05 – Monitoring](05-monitoring.md) with `nodetool gossipinfo` after the cluster is running.

## 📊 Data Distribution: Consistent Hashing

Cassandra uses **consistent hashing** to distribute data across nodes:

1. **Partition key → token**: The partition key is hashed (using Murmur3 by default) to produce a token value.
2. **Token → node**: Each node owns a range of tokens. With vnodes, each node owns multiple small ranges.
3. **Replica placement**: Replicas are placed on subsequent nodes in the ring according to the replication strategy.

**Example**: With RF=3 and a partition key that hashes to token `100`, replicas are stored on:
- The node owning token `100` (primary)
- The next node in the ring (replica 1)
- The node after that (replica 2)

💡 The **snitch** (e.g., `GossipingPropertySnitch`) ensures replicas are spread across different racks and datacenters when possible.

## 💾 Storage Engine: How Data is Written

When you write data, Cassandra follows this path:

1. **Writes to commit log** (durable, append-only): Ensures durability even if the node crashes before flushing to disk.
2. **Writes to memtable** (in-memory structure): Fast writes, sorted by partition key.
3. **Flushes to SSTable** (on disk): When memtable reaches a threshold (`memtable_flush_writers`), it's written to disk as an immutable SSTable file.

**SSTables (Sorted String Tables):**
- Immutable: once written, never modified
- Sorted by partition key for efficient reads
- Multiple SSTables per table (one per flush)
- Compaction merges SSTables to improve read performance and reclaim space

**File locations:**
- **Commit log**: `/var/lib/cassandra/commitlog/`
- **SSTable**: `/var/lib/cassandra/data/<keyspace>/<table>/`

## 📖 How Data is Read

When you read data, Cassandra follows this path:

1. **Checks memtable** (in-memory): Recent writes not yet flushed.
2. **Reads from SSTables**: Checks multiple SSTables (newest first) to find the latest version of each cell.
3. **Merges results**: Combines data from memtable and SSTables, using timestamps to determine the latest value.
4. **Read repair** (optional): If consistency level requires it, checks other replicas and repairs inconsistencies.

💡 **Bloom filters**: Each SSTable has a Bloom filter (in memory) that quickly tells Cassandra "this partition definitely isn't here" or "it might be here." This avoids reading SSTables that don't contain the partition.

**Read performance factors:**
- 📊 Number of SSTables (fewer = faster, achieved via compaction)
- 💾 Cache hit rate (row cache, key cache)
- 🔍 Bloom filter effectiveness

## 🔧 Data Maintenance: Compaction

**Compaction** merges multiple SSTables into fewer, larger SSTables. This:
- ⚡ Reduces read latency (fewer files to check)
- 💾 Reclaims space from deleted/updated data
- 🔄 Merges data from the same partition across SSTables

**Compaction strategies:**
- **SizeTieredCompactionStrategy (STCS)**: Merges SSTables of similar size. Simple but can create large temporary space requirements.
- **LeveledCompactionStrategy (LCS)**: Organizes SSTables into levels (L0, L1, L2...). More predictable space usage, better for read-heavy workloads.
- **TimeWindowCompactionStrategy (TWCS)**: Groups SSTables by time windows. Ideal for time-series data with TTLs.

💡 **In the lab (once the cluster is up)**: You will check compaction in [05 – Monitoring](05-monitoring.md) with `nodetool compactionstats` and in [07 – Repair & Maintenance](07-repair-maintenance.md).

## 🔄 Data Consistency: Repair Mechanisms

Cassandra provides three mechanisms to keep replicas consistent:

### 1. ⚡ Hinted Handoff (Write Path)

If a replica node is down during a write:
- The coordinator stores a **hint** locally
- When the node comes back up, the hint is delivered
- Hints expire after `max_hint_window_in_ms` (default: 3 hours)

⚠️ **Limitation**: Hints are only stored if the coordinator is in the same datacenter as the down node (or if `hinted_handoff_enabled` allows cross-DC hints).

### 2. 🔍 Read Repair (Read Path)

When reading with a consistency level that contacts multiple replicas:
- If replicas return different values, Cassandra returns the latest (by timestamp) to the client
- In the background, it updates the stale replicas with the latest value

✅ **Automatic**: Happens during normal reads; no separate command needed.

### 3. 🔧 Anti-Entropy Repair (Manual)

**Anti-entropy repair** (`nodetool repair`) is a background process that:
- Compares Merkle trees (hash trees) of data ranges between replicas
- Identifies and repairs inconsistencies
- Should be run regularly (weekly is common)

⚠️ **Why it's needed**: Hints expire, nodes can be down longer than the hint window, or corruption can occur. Anti-entropy repair is the definitive way to ensure consistency.

💡 **In the lab (once the cluster is up)**: You will run and monitor repair in [07 – Repair & Maintenance](07-repair-maintenance.md).

## ⚰️ Tombstones: How Deletes Work

Cassandra doesn't immediately delete data. Instead, it writes a **tombstone** (a marker indicating the data is deleted):

1. **Delete operation**: Writes a tombstone with a timestamp
2. **Reads**: Tombstones are returned like regular data (with a null value)
3. **Compaction**: Tombstones are removed after `gc_grace_seconds` (default: 10 days) if all replicas have been repaired

**Why tombstones:**
- ✅ Ensures deletes propagate to all replicas
- 🔄 Handles the case where a replica was down during the delete

⚠️ **Tombstone problems:**
- Too many tombstones can slow reads and waste space
- If `gc_grace_seconds` expires before repair runs, deleted data can "resurrect"

💡 **Best practice**: Run repair more frequently than `gc_grace_seconds` (e.g., weekly repair with 10-day grace period).

## 📊 Write Patterns and Read Performance

**Write pattern impact:**
- ✅ **Append-only writes** (new partitions): Fast, no read-before-write
- ⚡ **Updates** (same partition): Fast writes, but creates multiple versions across SSTables (compaction merges them)
- ⚰️ **Deletes**: Create tombstones that must be handled during reads and compaction

**Read pattern impact:**
- ⚡ **Partition-level reads** (by partition key): Very fast, single SSTable lookup
- 🐌 **Range scans** (multiple partitions): Slower, may touch many SSTables
- ⚠️ **Secondary indexes**: Can be slow; consider materialized views or denormalization for production

## 📝 Summary: Key Takeaways

**Core concepts:**
- 🔗 **Gossip** enables decentralized cluster discovery and failure detection
- 📊 **Consistent hashing** distributes data evenly; **vnodes** make rebalancing faster
- 💾 **Write path**: Commit log → memtable → SSTable (durable and fast)
- 📖 **Read path**: Memtable + multiple SSTables → merge by timestamp
- 🔧 **Compaction** keeps reads fast by reducing SSTable count
- 🔄 **Repair** (anti-entropy) is essential for long-term consistency
- ⚰️ **Tombstones** ensure deletes propagate but require regular repair

**Operational benefits:**
Understanding these mechanisms helps you:
- ⚙️ Choose appropriate consistency levels
- 📅 Schedule repair operations
- 🔧 Tune compaction strategies
- 🐛 Troubleshoot performance issues
- 📈 Plan for capacity and scaling

## 🚀 Next

Go to [02 – Cluster Architecture](02-cluster-architecture.md) to learn about DSE topology, replication, and consistency levels, then continue to [03 – Environment](03-environment.md) to set up your Docker or Colima lab environment.
