# Module 05 — Monitoring

Use **nodetool** (and JMX/logs) to monitor DSE 6.8/6.9 cluster health and performance. All commands are run in the Docker or Colima environment from the repo root.

💡 **DSE 6.9 Note**: Monitoring metrics remain consistent between DSE 6.8 and 6.9, but you may notice improved performance metrics (faster repair, streaming) in DSE 6.9 due to zero-copy streaming.

## 🎯 Goals

- 📊 Use essential nodetool commands for operations
- 🔍 Interpret status, info, and metrics from nodetool
- 🐛 Relate nodetool to JMX and logs for troubleshooting

## 🚀 Running nodetool

From the repo root:

```bash
./scripts/nodetool.sh <command> [args]
```

💡 **To run on another node** (e.g. dse-node-1 or dse-node-2):

```bash
./scripts/nodetool-node.sh dse-node-1 status
```

## 📊 Essential nodetool Commands

### ✅ status

Shows the ring: state, load, tokens, owns, host ID.

```bash
./scripts/nodetool.sh status
```

**State indicators:**
- ✅ **UN** = Up Normal (healthy).
- ❌ **DN** = Down Normal (node stopped or unreachable).
- 🔄 **UJ** = Up Joining (new node bootstrapping).

### 📊 info

Summary for the **dse-seed** node: uptime, heap, load, cache hit rate, etc.

```bash
./scripts/nodetool.sh info
```

💡 **To run on another node** (e.g. **dse-node-1** or **dse-node-2**), use **nodetool-node.sh** with the service name:

```bash
./scripts/nodetool-node.sh dse-node-1 info
./scripts/nodetool-node.sh dse-node-2 info
```

🔍 **What to look for:**
- 💾 **Heap (memory)** — Used vs max heap. If usage is consistently near the max, the JVM will GC heavily and latency can spike. Plan to increase heap or reduce load; avoid using more than ~½ of RAM for heap so the OS has room for page cache.
- 📈 **Load** — Total bytes of data on disk for this node (SSTables, etc.). Use it to compare nodes (balance), track growth over time, and size repairs/backups.
- ⚡ **Cache hit rate** — Key cache and row cache hit rates (if enabled). Low hit rates mean more disk I/O and higher read latency; consider tuning cache size or access patterns.
- ⏱️ **Uptime** — Restarts or short uptime can explain recent slowness or ring changes.
- ⚠️ **Overload** — No single metric here; combine high heap usage, low cache hit rate, and high load relative to other nodes as signs the node may be overloaded or unbalanced.

### describecluster

Prints cluster name, snitch, partitioner, and schema version.

```bash
./scripts/nodetool.sh describecluster
```

To run on another node (e.g. **dse-node-1** or **dse-node-2**), use **nodetool-node.sh** with the service name:

```bash
./scripts/nodetool-node.sh dse-node-1 describecluster
./scripts/nodetool-node.sh dse-node-2 describecluster
```

**What to look for:**

- **Cluster name** — Confirms you’re talking to the intended cluster (handy with multiple clusters or remotes).
- **Snitch** — How the cluster infers rack/DC for replication. Must be the same on every node; wrong or mixed snitches cause bad replica placement and can break multi-DC.
- **Partitioner** — Usually `Murmur3Partitioner`. Must match on all nodes; changing it would require a full cluster rebuild.
- **Schema version** — Should be identical across all nodes. If one node shows a different version, schema gossip hasn’t converged (restart that node or fix connectivity); don’t run schema changes until versions match.

### 🔗 ring

Shows token ranges and which node owns them. The ring is cluster-wide, so the output is the same no matter which node you run it on.

```bash
./scripts/nodetool.sh ring
```

🔍 **What to look for:**
- ✅ **All nodes present** — Every node you expect is in the ring; no missing nodes (connectivity or startup issue) and no unexpected ones (wrong cluster or duplicate).
- 📊 **State** — Each node should show **UN** (Up Normal). **DN** (Down Normal) means the node is down or unreachable; **UJ** (Up Joining) is normal only while a node is bootstrapping.
- ⚖️ **Token distribution** — With vnodes, each node has many token ranges. Ranges should be spread across nodes without one node owning a much larger share; imbalance can mean hotspots or a bad token assignment.
- 🔄 **After topology changes** — After adding a node, it should appear with its tokens and eventually show UN; after decommissioning or removing, that node should no longer appear in the ring.

### tablestats / tablehistograms

Per-keyspace/table stats (SSTables, read/write latency, etc.):

```bash
./scripts/nodetool.sh tablestats training # training being the lab keyspace
./scripts/nodetool.sh tablehistograms training sample # sample being the lab table
```

Use **tablehistograms** for read/write latency and throughput per table (replaces dashboard-style metrics you might otherwise get from a UI).

**What to look for (health & tricky workloads):**

- **SSTable count per table** — High numbers mean many small SSTables, more compaction work, and read amplification. If a table’s SSTable count keeps growing, compaction can’t keep up: throttle writes, add capacity, or check for a consumer that writes in bursts. This is a key signal for keeping the node healthy.
- **Space (disk) per table/keyspace** — Which tables use the most disk and how fast they grow. Helps plan capacity, backups, and repairs; also spots a single keyspace or table dominating disk.
- **Read/write latency (tablehistograms)** — High p95/p99 read or write latency on a table points to slow queries, large partitions, or overload. Compare tables to find which consumer or workload is driving the pain.
- **Read/write throughput per table** — Which tables have the highest read and write rates. Identifies “noisy” or tricky workloads: heavy writers that fuel compaction, or heavy readers that stress cache and disk. Use this to have data-driven conversations with app owners and to tune or isolate busy tables.
- **Cross-node comparison** — Run **tablestats** / **tablehistograms** on several nodes (e.g. `./scripts/nodetool-node.sh dse-node-1 tablestats`). If one node shows much higher load or latency for the same table, you may have a hotspot or an unbalanced workload.

Regularly reviewing tablestats and tablehistograms helps keep Cassandra healthy and quickly surfaces which consumers or tables are running tricky workloads so you can tune, scale, or fix them before they impact the whole cluster.

### netstats

Shows active streaming and connections to other nodes (e.g. after repair or bootstrap).

```bash
./scripts/nodetool.sh netstats
```

**What to look for:**

- **Active streaming** — After repair, bootstrap, or rebuild you should see streaming in/out; progress and throughput indicate whether the operation is healthy. Stuck or zero-throughput streams can mean network issues or a hung peer.
- **Connections** — Each node should show connections to its peers. "Not connected" or missing a peer means connectivity or firewall issues; fix before running repair or topology changes.
- **Idle** — When no repair/bootstrap/rebuild is running, streaming sections are typically idle. Ongoing streaming when you didn't start an operation can indicate background repair or a stuck stream.

### tpstats

Thread pool stats: pending and completed tasks per pool (e.g. read, write, compaction).

```bash
./scripts/nodetool.sh tpstats
```

**What to look for:**

- **Pending per pool** — High pending on **Read** or **Write** means the node can't keep up: clients are queued, latency will rise. High pending on **Compaction** means compaction is backlogged; consider tuning compaction throughput or adding capacity.
- **Completed counts** — Show relative activity (reads vs writes vs compaction). Use them to see which pool is busiest and to confirm that work is actually finishing.
- **Blocked or dropped** — Some pools report blocked or dropped tasks; non-zero values indicate overload or timeouts and warrant investigation.
- **Overload** — No single threshold; combine high pending read/write with high latency (e.g. from **tablehistograms**) and **info** heap/load to confirm the node is overloaded.

### compactionstats

Current and pending compactions.

```bash
./scripts/nodetool.sh compactionstats
```

**What to look for:**

- **Active compactions** — How many compactions are running and for which keyspaces/tables. A steady level is normal; a constant max (e.g. all compaction threads busy) plus growing pending means compaction can't keep up.
- **Pending** — Size of the compaction queue. If pending grows over time, writes are producing SSTables faster than compaction merges them; address with compaction throughput, write throttling, or capacity. Correlate with **tablestats** SSTable counts.
- **Long-running compactions** — Very long-running tasks can indicate huge SSTables, disk I/O issues, or a node under heavy load; check **tpstats** and disk/IO metrics.

### gossipinfo

Gossip state (heartbeats, generation). Useful for troubleshooting “node not seen” issues.

```bash
./scripts/nodetool.sh gossipinfo
```

**What to look for:**

- **All nodes present** — Every node in the cluster should appear. Missing nodes mean gossip hasn't propagated or there's a connectivity/partition issue; the "node not seen" side may be down or unreachable.
- **Generation** — Increments on node restart. A changed generation for a node means it restarted; useful to correlate with "node disappeared" or schema/ring changes.
- **Heartbeat / state** — Stale or old timestamps for a peer suggest network or clock issues. Use this together with **status** and **ring** to see why a node is DN or not in the ring.
- **Schema version** — Should match across nodes; mismatches here align with **describecluster** schema version and mean schema gossip hasn't converged.

### getcompactionthroughput / setcompactionthroughput

Inspect or set compaction throughput (MB/s). Lower values reduce I/O pressure.

```bash
./scripts/nodetool.sh getcompactionthroughput
./scripts/nodetool.sh setcompactionthroughput 16
```

**What to look for:**

- **Current value** — Baseline is often 16–32 MB/s. High values (e.g. 128+) increase I/O and can compete with reads/writes; low values reduce pressure but can let the compaction queue grow.
- **When to lower** — If the node is I/O-bound, read/write latency is high, or **tpstats** shows many pending reads/writes, lower compaction throughput to give application traffic priority. Use **compactionstats** to confirm pending doesn't grow unbounded.
- **When to raise** — If **compactionstats** pending keeps growing and the node has I/O headroom, raise throughput to catch up. Don't set so high that compaction starves reads and writes.
- **Persistence** — Changes are typically in-memory only until applied via config or restart; document and apply the desired value in configuration for durability.

## JMX and Metrics

**JMX** (Java Management Extensions) is the standard way Java applications expose management and monitoring. DSE runs in the JVM and registers **MBeans** (managed beans): attributes (metrics like heap usage, load, latency) and operations (e.g. trigger repair, flush, set compaction throughput). **nodetool** is a JMX client: it connects to DSE over JMX (default port **7199**) and reads attributes or invokes operations. If JMX is not reachable (firewall, wrong host/port, or DSE down), nodetool fails.

Metrics you see in **info** and **tablestats** / **tablehistograms** come from these MBeans:
- **Heap** — JVM heap usage (e.g. from `info`).
- **Load** — Total bytes stored on disk.
- **Read/Write latency** — From `tablehistograms` (e.g. `./scripts/nodetool.sh tablehistograms training sample`).

For production, you can expose JMX to external monitoring (e.g. Prometheus via a JMX exporter, Grafana) or use the same nodetool/tablehistograms output in scripts to build dashboards and alerts.

## Logs

Monitoring also includes **logs**. You can view logs in two ways:

**Option 1: Using the logs script (recommended):**

```bash
# Follow all DSE node logs
./scripts/logs.sh

# Follow logs for a specific node
./scripts/logs.sh dse-seed
./scripts/logs.sh dse-node-1

# View last 50 lines without following
./scripts/logs.sh dse-seed --tail 50
```

**Option 2: Inside the container:**

```bash
./scripts/shell.sh
# Then inside the container:
tail -f /var/log/cassandra/system.log
```

Use `./scripts/shell.sh dse-node-1` or `./scripts/shell.sh dse-node-2` to view logs on another node.

**What to look for (performance and stability):**

- **GC pauses** — Log lines mentioning GC pauses or long GC times (e.g. "GC for … took … ms") indicate the JVM is spending too much time in garbage collection. Long or frequent pauses cause request latency spikes and can make the node appear unresponsive. Correlate with **nodetool info** heap usage: if heap is near max, increase heap or reduce load; tune GC (e.g. G1GC goals) if pauses remain high.
- **Compaction** — Compaction-related messages (e.g. "Compacting", "Compaction … completed") are normal; a flood of compaction activity or repeated failures can mean compaction backlog or I/O issues. Cross-check with **compactionstats** and **tpstats**.
- **Timeouts and failures** — "Read timeout", "Write timeout", or "Unavailable" in logs point to overload, slow replicas, or network issues. Look for patterns (same table, same node) and correlate with **tablehistograms** latency and **tpstats** pending.
- **Exceptions and errors** — OOM (OutOfMemoryError), disk full, or uncaught exceptions indicate stability problems. Address immediately: fix config, add capacity, or fix the failing operation.
- **Gossip and connectivity** — "Node … is now down" or "Unable to reach …" suggest partition or node failure; use **nodetool status** and **gossipinfo** to confirm ring and gossip state.

🐛 See [08 – Troubleshooting](08-troubleshooting.md) for more on logs and common failures.

## 🚀 Next

Go to [06 – Backup & Restore](06-backup-restore.md) for snapshots and incremental backup.
