# Module 07 — Repair & Maintenance

Run **anti-entropy repair** and routine **maintenance** so the cluster stays consistent and disk usage is under control. All commands target the Docker Compose cluster.

## 🎯 Goals

- 🔍 Understand why repair is needed (replica drift, hints, failures)
- 🔄 Understand **NodeSync** (DSE 6 continuous background repair) vs traditional repair
- 🔧 Run **nodetool repair** with common options (full vs incremental, primary-only, DC-local)
- 🧹 Run **nodetool cleanup** after topology changes
- 💾 Relate repair to backup (run cleanup before backup when appropriate)

## 🔧 Why Repair?

**Replicas can diverge** due to writes during node outages, hints, or compaction differences.

- **Anti-entropy repair** (nodetool repair) compares Merkle trees between replicas and streams missing or differing data so replicas converge.

💡 **Best practice**: Run repair regularly (e.g. within the **gc_grace_seconds** window for each table, typically every 10 days or as per policy).

## Repair on the read and write paths (and hinted handoff)

DSE/Cassandra has **repair-related behavior on both the read path and the write path**, plus **hinted handoff**. None of these replace scheduled **nodetool repair** (anti-entropy); they reduce or defer inconsistency.

### Write path: replication and hinted handoff

- On **write**, the coordinator sends the mutation to all replicas according to the consistency level (e.g. QUORUM = wait for a quorum of acks).
- If a **replica is down**, the coordinator can still satisfy the CL by writing to the remaining replicas. For the down replica, the coordinator may store a **hint**: a copy of the mutation to be replayed when that node comes back. This is **hinted handoff**—repair during the write path.
- **Hinted handoff** = best-effort. Hints are stored on the coordinator (in a hints directory), replayed when the target node is back, then deleted. They do **not** guarantee delivery: hints are only kept for a limited time (**max_hint_window_in_ms**, e.g. 3 hours); after that, new writes for that node are no longer hinted. So if a node is down longer than the hint window, it will have **missing writes** until **nodetool repair** runs.
- Summary: the write path tries to “repair” missing writes for temporarily down nodes via hints; it is not a substitute for anti-entropy repair.

### Read path: read repair

- On **read**, the coordinator queries enough replicas to satisfy the consistency level. If replicas return **different** data (or different timestamps), the coordinator reconciles and returns a result. It can also **repair** the out-of-date replicas so the next read sees consistent data—this is **read repair** (repair during the read path).
- **Blocking read repair** (e.g. in newer DSE/Cassandra): the coordinator may block the read until it has written the correct value to other replicas, then return. That gives monotonic quorum reads but adds latency.
- **Non-blocking / probabilistic read repair** (older configs: `read_repair_chance`, `dclocal_read_repair_chance`): the coordinator triggers a background repair for that partition with some probability; the read returns immediately. Only a subset of reads trigger repair, so some drift can remain.
- Read repair only fixes **partitions that are actually read**; it does not scan the whole keyspace. So replicas can still diverge on partitions that are rarely or never read. **nodetool repair** is still required for full coverage.

### How this ties together

| Mechanism | Path | What it does | Limitation |
|-----------|------|--------------|------------|
| **Hinted handoff** | Write | Replay missed writes to a node that was down when the write happened. | Best-effort; hint window limited; no guarantee. |
| **Read repair** | Read | When a read sees inconsistent replicas, update the stale replica(s). | Only repairs data that is read; not full anti-entropy. |
| **nodetool repair** (anti-entropy) | Scheduled | Compare Merkle trees and stream differences for all data in scope. | Full coverage; run regularly (e.g. within gc_grace_seconds). |

Run **nodetool repair** regularly so the cluster converges even when hints expire or partitions are seldom read.

## 🔄 NodeSync: Continuous Background Repair

**NodeSync** is a DSE 6 feature that provides continuous background repair, automatically validating and repairing data consistency without manual intervention. It can replace traditional `nodetool repair` for many workloads.

### What is NodeSync?

- **Continuous validation**: NodeSync continuously validates that data is in sync on all replicas
- **Automatic repair**: When inconsistencies are found, NodeSync repairs them automatically
- **Low impact**: Always running but designed to have minimal impact on cluster performance
- **Per-table**: Enabled on a per-table basis using CQL `ALTER TABLE`

### NodeSync vs Traditional Repair

| Aspect | NodeSync | nodetool repair |
|--------|----------|-----------------|
| **Mode** | Continuous background | Scheduled manual runs |
| **Coverage** | Full automatic coverage | Full coverage when run |
| **Effort** | No manual intervention | Requires scheduling and monitoring |
| **Performance** | Low impact, always running | Higher impact during execution |
| **CPU overhead** | May be higher for write-heavy workloads (>20% writes) | Lower overhead during scheduled runs |
| **Best for** | Most production workloads | Write-heavy workloads, or when NodeSync overhead is too high |

💡 **Recommendation**: For most workloads, NodeSync is preferred as it eliminates manual repair scheduling. However, for write-heavy workloads where more than 20% of operations are writes, you may notice CPU overhead; in those cases, DataStax recommends using `nodetool repair` instead.

### How NodeSync Works

1. **Service starts automatically**: NodeSync service starts when DSE starts (enabled by default)
2. **Tables opt-in**: Tables must explicitly enable NodeSync with `ALTER TABLE ... WITH nodesync = true`
3. **Segments**: NodeSync splits data ranges into small segments (typically ~200 MB each)
4. **Validation**: Each segment is validated by reading from all replicas and checking for inconsistencies
5. **Repair**: If inconsistencies are found, NodeSync repairs them automatically
6. **Incremental**: When incremental NodeSync is enabled, previously validated data is not re-validated, reducing workload

### Enabling NodeSync on Tables

Enable NodeSync for a table using CQL:

```cql
ALTER TABLE training.sample WITH nodesync = true;
```

To disable NodeSync:

```cql
ALTER TABLE training.sample WITH nodesync = false;
```

💡 **Important**: Once NodeSync is enabled on a table, `nodetool repair` operations that target all keyspaces or specific keyspaces will **automatically skip** tables with NodeSync enabled. Running `nodetool repair` against an individual table with NodeSync enabled will be **rejected**.

### Managing NodeSync Service

**Check NodeSync status:**

```bash
./scripts/nodetool.sh nodesyncservice status
```

**Enable NodeSync service** (if disabled):

```bash
./scripts/nodetool.sh nodesyncservice enable
```

**Disable NodeSync service**:

```bash
./scripts/nodetool.sh nodesyncservice disable
```

**Check current rate limit**:

```bash
./scripts/nodetool.sh nodesyncservice getrate
```

**Set rate limit** (temporarily, in KB/s):

```bash
./scripts/nodetool.sh nodesyncservice setrate 2048
```

💡 To persist the rate limit, configure `rate_in_kb` in `cassandra.yaml` instead of using `setrate`.

**Simulate rate requirements**:

```bash
./scripts/nodetool.sh nodesyncservice ratesimulator
```

This helps determine what rate is needed to meet the NodeSync deadline.

### When to Use NodeSync vs Traditional Repair

**Use NodeSync when:**
- ✅ You want automatic, continuous repair without manual scheduling
- ✅ Your workload is read-heavy or balanced (writes < 20% of operations)
- ✅ You want to eliminate manual repair operations
- ✅ You can accept some CPU overhead for continuous validation

**Use `nodetool repair` when:**
- ✅ Your workload is write-heavy (>20% writes) and NodeSync CPU overhead is too high
- ✅ You need explicit control over when repair runs
- ✅ You're troubleshooting specific consistency issues
- ✅ NodeSync is disabled or not available

### NodeSync Limitations

- **CPU overhead**: May exceed traditional repair for write-heavy workloads (>20% writes)
- **No special WAN optimizations**: May perform poorly on bad WAN links (multi-DC)
- **Requires configuration**: Must ensure rate is sufficient to meet `gc_grace_seconds` commitment
- **Lost SSTables**: If a node loses an SSTable (corruption), run manual validation

## Repair

- **Default repair type**: **Full**. Use `-inc` for incremental repair.
- **Primary (partitioner) range**: `-pr` repairs only the primary replica per partition (recommended for routine runs; less I/O and network).
- **Datacenter**: `-local` or `-dc <name>` to limit repair to one DC.
- **Sequential**: `-seq` repairs one node after another; default is parallel (all replicas in parallel).
- **Zero-copy streaming**: Both DSE 6.8 and 6.9 use zero-copy streaming, making repair operations significantly faster (up to 4x faster) compared to earlier versions.

## Repair options explained

| Option | Meaning | When to use |
|--------|--------|-------------|
| **`-pr`** (partitioner range) | Repairs only the **primary** replica of each partition on the node where you run the command. Does not repair secondary replicas on other nodes. | **Routine repair.** Less I/O and network; run regularly (e.g. within gc_grace_seconds). Each node runs repair for its primary ranges; over time the whole cluster is covered. |
| **`-full`** | **Full** anti-entropy repair: compares Merkle trees and streams differences for all replicas of the repaired ranges. | When you need strong consistency or after failures. Default repair type. Use with `-pr` for full primary-only repair. |
| **`-inc`** (incremental) | **Incremental** repair: only repairs data that has been compacted with incremental repair; faster but does not cover all data until full repair has been run. | When your tables use incremental repair and you want faster, incremental runs. Zero-copy streaming (available in DSE 6.8 and 6.9) makes incremental repair faster. |
| **`-local`** | Restricts repair to nodes in the **local datacenter** only (the DC of the node where you run the command). | Multi-DC clusters: repair one DC at a time to avoid cross-DC traffic; or to meet DC-local policies. |
| **`-dc <name>`** | Restricts repair to the specified **datacenter** by name. | When you want to repair a specific DC (e.g. `-dc DC1`). |
| **`-seq`** (sequential) | Runs repair **sequentially**: one node (or one range) after another instead of in parallel. | When parallel repair causes too much load or contention; can reduce impact at the cost of longer duration. |
| **`-st <token>` / `-et <token>`** | **Start token** and **end token**: repair only the given token range. | Debugging or repairing a specific range; rarely needed for routine runs. |
| **`-hosts <host>,...`** | Restricts repair to the listed **hosts** (by IP or hostname). | When you want to repair only between specific nodes. |
| **`-j <n>`** (job threads) | Number of **concurrent repair jobs** (e.g. 1–4). | Tune parallelism; higher values can speed repair but increase load. |
| **Keyspace / table** | Pass keyspace name, or keyspace and table name, as arguments before options. | Limit repair to one keyspace (e.g. `repair training -pr`) or one table (e.g. `repair training sample -pr`). |

**Typical combinations:** `repair -pr` or `repair -pr -full` for routine primary-only full repair; `repair -pr -local` or `repair -pr -dc DC1` to keep repair within one DC; `repair -pr -inc` for incremental when supported.

## Running Repair

### Primary-only repair (recommended for regular runs)

Repair only primary ranges for the **local** node (seed):

```bash
./scripts/nodetool.sh repair -pr
```

Repair primary ranges on **all** nodes (run on one node; it coordinates):

```bash
./scripts/nodetool.sh repair -pr -full
```

### Full repair, local DC

```bash
./scripts/nodetool.sh repair -local -full
```

### Incremental repair

```bash
./scripts/nodetool.sh repair -pr -inc
```

💡 **Note**: Zero-copy streaming (available in both DSE 6.8 and 6.9) makes incremental repair operations significantly faster compared to earlier versions.

### Repair a specific keyspace/table

```bash
./scripts/nodetool.sh repair training -pr
./scripts/nodetool.sh repair training sample -pr
```

## Monitoring Repair

- **nodetool compactionstats**: Repair runs as a form of compaction; you may see active compactions.
- **nodetool netstats**: Shows streaming (data transfer between nodes during repair).
- **Logs**: `docker-compose logs -f dse-seed` (Or: `docker compose logs -f dse-seed`) (or the node you run repair on).

Repair can take a long time on large clusters; run during low-traffic windows when possible.

## Cleanup

- **When**: After adding or removing nodes, so each node only keeps data for token ranges it owns.
- **What**: Removes SSTable data that no longer belongs to this node (e.g. after a node left or tokens changed).
- Run on **each** node; it’s local to that node.

```bash
./scripts/nodetool.sh cleanup
./scripts/nodetool-node.sh dse-node-1 cleanup
./scripts/nodetool-node.sh dse-node-2 cleanup
```

Run cleanup **before** taking a snapshot when you’ve done topology changes (see [06 – Backup & Restore](06-backup-restore.md)).

## Compaction

- **Compaction** merges SSTables and reclaims space; it’s automatic. You can tune throughput and see status.
- Check: `./scripts/nodetool.sh compactionstats`
- Set throughput (MB/s): `./scripts/nodetool.sh setcompactionthroughput 32`
- Force user compaction (use with care): `./scripts/nodetool.sh compact training sample`

## 🧪 Hands-On Exercises

### 🟢 Beginner: Basic Repair

1. Run primary-only repair on the seed:  
   `./scripts/nodetool.sh repair -pr`
2. Watch `./scripts/nodetool.sh netstats` while repair runs to see streaming activity.
3. Verify repair completed successfully by checking logs: `./scripts/logs.sh dse-seed --tail 20`

### 🟡 Intermediate: Repair with Monitoring

1. Run primary-only incremental repair: `./scripts/nodetool.sh repair -pr -inc`
2. In separate terminals, monitor:
   - `./scripts/nodetool.sh netstats` (streaming)
   - `./scripts/nodetool.sh compactionstats` (compaction activity)
3. Check repair progress in logs: `./scripts/logs.sh dse-seed`

### 🔴 Advanced: Full Repair Workflow

1. Run cleanup on all three nodes:
   ```bash
   ./scripts/nodetool.sh cleanup
   ./scripts/nodetool-node.sh dse-node-1 cleanup
   ./scripts/nodetool-node.sh dse-node-2 cleanup
   ```
2. Take a snapshot before repair: `./scripts/nodetool.sh snapshot training -t before_repair`
3. Run repair with specific keyspace: `./scripts/nodetool.sh repair training -pr`
4. Monitor repair progress and verify completion.
5. List snapshots: `./scripts/nodetool.sh listsnapshots`

### 🔄 NodeSync Exercise

1. **Check NodeSync service status**:
   ```bash
   ./scripts/nodetool.sh nodesyncservice status
   ```

2. **Enable NodeSync on a table**:
   ```bash
   ./scripts/cqlsh.sh -e "ALTER TABLE training.sample WITH nodesync = true;"
   ```

3. **Verify NodeSync is enabled**:
   ```bash
   ./scripts/cqlsh.sh -e "DESCRIBE TABLE training.sample;"
   ```
   Look for `nodesync = true` in the output.

4. **Check NodeSync rate**:
   ```bash
   ./scripts/nodetool.sh nodesyncservice getrate
   ```

5. **Try to repair the table** (should be rejected):
   ```bash
   ./scripts/nodetool.sh repair training sample -pr
   ```
   You should see an error indicating that NodeSync-enabled tables cannot be repaired manually.

6. **Disable NodeSync** (if you want to use traditional repair):
   ```bash
   ./scripts/cqlsh.sh -e "ALTER TABLE training.sample WITH nodesync = false;"
   ```

## Next

Go to [08 – Troubleshooting](08-troubleshooting.md) for logs, common failures, and recovery steps.
