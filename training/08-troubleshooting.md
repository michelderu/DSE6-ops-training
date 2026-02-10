# Module 08 — Troubleshooting

Find and fix common issues in a DSE 6.8/6.9 cluster using logs, nodetool, and basic recovery steps. All examples assume the Docker Compose environment.

## 🎯 Goals

- 📋 Locate and read DSE logs
- 🔍 Interpret **nodetool status** and **gossip**
- 🐛 Handle node down, bootstrap failures, and disk/GC issues at a basic level
- 📚 Know where to look in official docs for deeper fixes

## 📋 Logs

### 📁 Where logs live (inside the container)

**Log locations:**
- 📝 **System log**: `/var/log/cassandra/system.log` (often the first place to look)
- 🔍 **Debug log**: `/var/log/cassandra/debug.log`
- ⚙️ **GC log**: JVM GC logging (path depends on `JVM_EXTRA_OPTS` / log config)

💡 For a full list of important paths (config, logs, data) in the lab, see [03 – Environment – Important paths and files in the container](03-environment.md#important-paths-and-files-in-the-container).

### View logs

From repo root:

```bash
# Follow system log: open a shell in the seed container, then run tail -f
./scripts/shell.sh
# Inside the container:
tail -f /var/log/cassandra/system.log
# Use ./scripts/shell.sh dse-node-1 or dse-node-2 for other nodes.

# Last 200 lines (from host)
docker-compose logs --tail 200 dse-seed
# Or: docker compose logs --tail 200 dse-seed

# All logs from all DSE containers
docker-compose logs dse-seed dse-node-1 dse-node-2
# Or: docker compose logs dse-seed dse-node-1 dse-node-2
```

Look for **ERROR**, **WARN**, **Exception**, **OutOfMemoryError**, and **Disk full**.

## Node Down (DN)

**Symptom**: `nodetool status` shows **DN** for one or more nodes.

**Checks:**

1. **Is the process running?**  
   `docker-compose ps` (Or: `docker compose ps`) — is the container up?
2. **Can other nodes reach it?**  
   From another node: `nodetool gossipinfo` and check whether the down node appears and what generation/state it has.
3. **Network**: Can the host reach the node’s IP/port (e.g. 7000)? In Compose, ensure the `dse-net` network is healthy and no firewall is blocking internode ports.
4. **Logs**: On the down node (if it’s still running but not joining), check `system.log` for bind errors, OOM, or bootstrap failures.

**Actions:**

- Restart the node: `docker-compose restart <service_or_container>` (Or: `docker compose restart ...`)
- If the node is permanently gone (e.g. disk lost), use **nodetool removenode** from another node (see official DSE docs) and then replace the node.

## Bootstrap / Join Failures

**Symptom**: New node stays in **UJ** (Up Joining) or never appears as UN.

**Checks:**

1. **Seeds**: New node must have correct `SEEDS` (e.g. `dse-seed`). In Compose, `SEEDS=dse-seed` in the `node` service.
2. **Connectivity**: From the joining node, can it reach the seed on port 7000? Open a shell on the joining node (e.g. `./scripts/shell.sh dse-node-1`), then run `nc -zv dse-seed 7000` or use ping/telnet.
3. **Disk**: Bootstrap streams data; ensure the node has enough disk and that `/var/lib/cassandra` is writable.
4. **Logs**: On the joining node, `system.log` often shows “Unable to bootstrap” or streaming errors.

**Actions:**

- Fix seeds and network; restart the joining node.
- If bootstrap was partially done and the node is in a bad state, you may need to clear its data and re-bootstrap (see DSE docs for decommission/clear and re-add).

**"Other bootstrapping/leaving/moving nodes detected" (UnsupportedOperationException):**  
With `cassandra.consistent.rangemovement=true` (default), only one node may bootstrap at a time. If another node is still joining, a new node will refuse to bootstrap with this exception. Our `docker-compose.yml` sets `JVM_EXTRA_OPTS=-Dcassandra.consistent.rangemovement=false` for the lab so multiple nodes can bootstrap. If you still see this (e.g. after removing that setting), bring the cluster down, then bring it up with `./scripts/up-cluster.sh` so nodes start one after another.

## OutOfMemoryError (OOM)

**Symptom**: Node crashes or logs show **OutOfMemoryError** / **java.lang.OutOfMemoryError: Java heap space**.

**Checks:**

- **Heap size**: In our Compose we set `JVM_EXTRA_OPTS=-Xms1g -Xmx1g`. For more data or load, increase (e.g. `-Xms2g -Xmx2g`) in `.env` and restart.
- **nodetool info**: Check “Heap” usage; if it’s constantly near 100%, heap is too small or there’s a leak.

**Actions:**

- Increase heap (and ensure the host has enough RAM). Restart the node.
- Check for large queries or compactions; tune compaction throughput if needed.

## Disk Full

**Symptom**: Writes fail or logs show “No space left on device”.

**Checks:**

- **Host**: `df -h` on the host (and inside the container if needed). Our data is in the local `./data/` directory (seed, node1, node2).
- **Snapshots**: Old snapshots consume space. List with `nodetool listsnapshots` and clear with `nodetool clearsnapshot` (see [06 – Backup & Restore](06-backup-restore.md)).

**Actions:**

- Free disk: remove old snapshots, compact/cleanup, or expand the volume.
- Prevent: schedule snapshot retention and monitor disk usage (e.g. nodetool tablestats, host monitoring).

## Repair / Streaming Hanging

**Symptom**: Repair or bootstrap seems to stall (no progress for a long time).

**Checks:**

- **nodetool netstats**: Is data streaming? Large partitions or slow disk can make streaming slow.
- **nodetool compactionstats**: Repair uses compaction; check for many pending compactions.
- **Logs**: Look for timeout or connection errors between nodes.

**Actions:**

- Allow more time on large clusters; run during low load.
- If a replica is down, repair may block until it’s back (or you use options that skip it—see DSE docs). Bring the node up or remove it from the ring first.

## Quick Reference

| Issue        | Where to look                    | Typical action                    |
|-------------|-----------------------------------|-----------------------------------|
| Node DN     | `docker-compose ps` (Or: `docker compose ps`), gossip, logs | Restart container; fix network   |
| Join fails  | SEEDS, connectivity, disk, logs   | Fix config/network; clear & re-add if needed |
| OOM         | Heap in nodetool info, logs       | Increase heap; restart            |
| Disk full   | `df`, snapshots                   | Clear snapshots; add disk         |
| Repair slow | netstats, compactionstats, load   | Run in off-peak; tune compaction  |

## Official References

- [DSE 6.8 Operations](https://docs.datastax.com/en/dse/6.8/managing/operations/)
- [DSE 6.9 Operations](https://docs.datastax.com/en/dse/6.9/managing/operations/)
- [DSE 6.8 Troubleshooting](https://docs.datastax.com/en/dse/6.8/managing/troubleshooting/)
- [DSE 6.9 Troubleshooting](https://docs.datastax.com/en/dse/6.9/managing/troubleshooting/)
- [DSE 6.8 nodetool](https://docs.datastax.com/en/dse/6.8/managing/tools/nodetool/)
- [DSE 6.9 nodetool](https://docs.datastax.com/en/dse/6.9/managing/tools/nodetool/)

## 🧪 Troubleshooting Scenarios

Practice troubleshooting with intentionally broken states. See [Troubleshooting Scenarios](labs/troubleshooting-scenarios.md) for hands-on exercises.

## 🚀 Next

Go to [09 – DSE Config](09-dse-config.md) for DSE-specific configuration tasks, including configuration encryption with `dsetool`.
