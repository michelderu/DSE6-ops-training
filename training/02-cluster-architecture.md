# Module 02 — Cluster Architecture

Understand how DataStax Enterprise 6.8 and 6.9 are structured so you can operate and troubleshoot them effectively.

## Goals

- Describe cluster, datacenter, rack, and node roles
- Explain replication and consistency in simple terms
- Relate these concepts to your Docker Compose cluster

## Cluster Topology

### Cluster → Datacenter → Rack → Node

- **Cluster**: One logical DSE deployment (one ring). Our lab cluster name is `DSE`.
- **Datacenter (DC)**: A group of nodes for replication and workload. Our lab has a single DC: `DC1`.
- **Rack**: A failure domain inside a DC (e.g. one rack = one cabinet). Used by the snitch for placement. Our lab uses `Rack1`.
- **Node**: A single DSE process (one machine or container). Each node holds a portion of the ring and replicas.

In Docker Compose we have **3 nodes** in **1 DC**, all in the same logical “rack” for simplicity.

### Seed Nodes

- **Seeds** are contact points for new nodes joining the cluster. They do not hold more data than other nodes.
- In our setup, **dse-seed** is the only seed. Other nodes use `SEEDS=dse-seed` to discover the cluster.
- Best practice: define 2–3 seeds per DC in production; for the lab, one seed is enough.

## Data Distribution: Partitioning and Replication

### Partition Key and Tokens

- Data is stored in **partitions**. Each partition is identified by a **partition key**.
- The partition key is hashed to a **token**. Tokens determine which node(s) own the partition.
- Each node is responsible for a range of tokens (the **ring**). With **vnodes** (default in DSE 6.8/6.9), each node has multiple small token ranges (e.g. 256 tokens per node).

**Added value of vnodes:** More even data distribution across the ring (no “hot” nodes from uneven manual token ranges). When you add or remove nodes, rebalancing streams many small ranges in parallel instead of a few large ones, so the cluster rebalances faster and no single node is overloaded. You also avoid manual token assignment: the cluster assigns vnodes automatically.

### Replication

- **Replication factor (RF)** is set per keyspace (e.g. `RF=3` in DC1 means three copies of each partition in DC1).
- Replicas are placed according to the **replication strategy** and **snitch**:
  - **NetworkTopologyStrategy**: You specify how many replicas per DC (e.g. `'DC1': 3`). Used for production and in our training keyspace.
  - **SimpleStrategy**: Single-DC only; you only set a number (e.g. RF=3). Good for dev/test.

In our 3-node cluster, `training` with `'DC1': 3` means every partition has one replica on each node.

**Where it’s defined in this training:**

In `./training/labs/sample-keyspace.cql`, replication is set when the keyspace is created: `CREATE KEYSPACE training WITH replication = { 'class': 'NetworkTopologyStrategy', 'DC1': 3 };`. That’s the `'DC1': 3` (RF=3 in DC1) and the strategy (NetworkTopologyStrategy).

**How to see it at runtime:**

From the repo root, run `./scripts/cqlsh.sh -e "DESCRIBE KEYSPACE training;"` (or open cqlsh with `./scripts/cqlsh.sh` and run `DESCRIBE KEYSPACE training;`). The output shows the keyspace definition, including the replication map.

## ⚖️ Consistency Levels

- **Consistency level (CL)** defines how many replicas must respond for a read or write to be considered successful.

**Common levels:**
- ⚡ **ONE**: One replica (fast, less durable).
- ⚖️ **QUORUM**: Majority of replicas (e.g. 2 of 3). Good balance of safety and latency.
- 🔒 **ALL**: Every replica. Strongest, slowest.
- 🌐 **LOCAL_ONE** / **LOCAL_QUORUM**: Same but only in the local DC (multi-DC).

💡 **For a single-DC cluster with RF=3**: **QUORUM** (2 replicas) is a common choice for both reads and writes.

📝 **Examples (in cqlsh)**: Set the default CL for the session with `CONSISTENCY <level>;`, or use it per statement. From the repo root, run `./scripts/cqlsh.sh`, then:

```cql
-- Use QUORUM for this session (default for many apps)
CONSISTENCY QUORUM;

-- Read with ONE (fast, may return stale data)
CONSISTENCY ONE;
SELECT * FROM training.sample LIMIT 1;

-- Write with QUORUM (durable, 2 of 3 replicas must ack)
CONSISTENCY QUORUM;
INSERT INTO training.sample (id, name, value, created_at) VALUES (uuid(), 'test', 42, toTimestamp(now()));

-- Per-statement CL (DSE/Cassandra 2.1+): USING CONSISTENCY
SELECT * FROM training.sample LIMIT 1 USING CONSISTENCY ONE;
```

💡 Check the current session CL with `CONSISTENCY;` (no argument).

## 🧩 Components in DSE 6.8/6.9

**Available components:**
- ✅ **Cassandra core**: CQL, storage engine, compaction, repair (what we use in this training).
- 🔍 **DSE Search** (Solr): Full-text search — optional (not covered in this training).
- 📊 **DSE Analytics** (Spark): Batch/streaming — optional (not covered in this training).
- 🕸️ **DSE Graph**: Graph model and Gremlin — optional (not covered in this training).
- 📊 **Storage-Attached Indexing (SAI)**: DSE 6.8+ feature for improved indexing performance (not covered in this training).

💡 **Our Docker Compose image** runs the **database (transactional)** profile only.

💡 **DSE 6.9 improvements**: DSE 6.9 includes significant performance improvements including 4x faster streaming and zero-copy streaming capabilities, making node recovery and addition much faster than previous versions.

📚 **For deeper understanding of Cassandra internals**, see [01 – Database Architecture](01-database-architecture.md) which covers gossip, storage engine, reads/writes, compaction, and repair mechanisms in detail.

## 🔌 Ports (Reference)

| Port | Purpose |
|------|--------|
| 9042 | CQL native (clients) |
| 9160 | Thrift (legacy) |
| 7000 | Internode (gossip, streaming) |
| 7199 | JMX (monitoring, nodetool) |

## 🧪 Relating This to Your Lab

**Lab configuration:**
- **Cluster**: `DSE` (from `CLUSTER_NAME` in Compose).
- **DC**: `DC1` (from `DC` in Compose).
- **Nodes**: `dse-seed` + 2 scaled `node` containers; all in `DC1`, `Rack1`.
- **Seeds**: Only `dse-seed`. Other nodes join via `SEEDS=dse-seed`.
- **Keyspace**: `training` with `NetworkTopologyStrategy` and `'DC1': 3` — every row is replicated to all 3 nodes.

## 🚀 Next

Go to [03 – Environment](03-environment.md) to set up your Docker or Colima lab environment, then continue to [04 – Lifecycle](04-lifecycle.md) to start, stop, and inspect the cluster and scale nodes.
