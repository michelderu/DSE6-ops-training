# Module 06 — Backup & Restore

Use DSE 6.8/6.9 **snapshots** and **incremental backup** to protect data, and restore when needed. All steps use the Docker Compose cluster.

## 🎯 Goals

- 💾 Create and list **snapshots** (full backup)
- 🔄 Enable and use **incremental backup**
- 🔙 Restore from snapshot (conceptually and with basic steps)
- 🧹 Run **cleanup** before backup when appropriate

## Core data concepts
Before diving into backup and restore, let's clarify some core storage concepts in DSE/Cassandra:

### Commit Log
The **commit log** is an append-only file stored on disk where all write operations (INSERT/UPDATE/DELETE) are recorded for durability. Whenever you write data, it is written to the commit log before it's acknowledged, ensuring that even if a node crashes, unflushed writes can be recovered.

### Memtable
A **memtable** is an in-memory data structure (similar to a write-back cache) that holds recently written data. Data in the memtable is fast to access, but is volatile and will be lost if the process stops unexpectedly. Entries in the memtable are periodically flushed to disk as immutable files.

### SSTable
An **SSTable** (Sorted String Table) is an immutable data file created when a memtable is flushed to disk. SSTables are the persistent, durable storage of your data and can be merged or compacted for space efficiency and performance. All on-disk table data ultimately resides in SSTables.

**Write Path Summary:**  
1. Client issues a write (CQL statement).
2. Write is appended to the **commit log** (disk) and added to the **memtable** (RAM).
3. When the memtable is full or a flush is triggered, contents are written as a new **SSTable** (disk).
4. The associated commit log segment can be safely discarded for the flushed data.

Understanding these concepts is essential because:
- **Backups** (snapshots, incremental) work at the SSTable (and optionally commit log) level.
- **Restores** involve copying or replaying these files to return a table, keyspace, or cluster to an earlier state.

**Diagram of the write path:**

`Client Write → Commit Log (disk, durable) + Memtable (memory) → Flush → SSTable (disk, durable)`

## Understanding the data lifecycle
Understanding where data lives helps you reason about backup and restore.

**Ingestion (writes)**  
When a client writes (CQL INSERT/UPDATE), the coordinator node appends the mutation to the **commit log** on disk (for durability) and applies it to an in-memory **memtable**. Writes are not applied directly to SSTables. When a memtable is full or explicitly flushed, DSE writes it to disk as a new **SSTable** (immutable). The commit log can then be recycled for that data. So the write path is: *client → commit log + memtable → flush → SSTable on disk*.

**On disk**  
Table data ultimately lives under the data directory (e.g. `/var/lib/cassandra/data/<keyspace>/<table>/`) as **SSTable** files (`.db` and related). Snapshots are subdirectories under that path (e.g. `snapshots/<snapshot_name>/`). The **commit log** is in a separate directory and is replayed on restart to recover unflushed mutations.

**Compaction**  
Over time, DSE **compacts** SSTables: it merges multiple SSTables into fewer, larger ones to bound read amplification and reclaim space from overwritten or deleted data. Compaction does not change the logical data; it only reorganizes how it is stored on disk.

**Queries (reads)**  
A read is satisfied from the **memtable** (recent writes), **row cache** and **key cache** (if enabled), and **SSTables** on disk. DSE may read from several SSTables and merge results. So the read path is: *client → coordinator → memtable + caches + SSTables on disk*.

**Why this matters for backup**  
Backups protect the durable state: **commit log** (in-flight writes) and **SSTables** (flushed data). Snapshots are a point-in-time copy of SSTables for a keyspace/table. Incremental backup tracks which SSTables (and optionally commit logs) have been produced since the last backup so you can copy only what changed.

## Backup concepts

- **Snapshot**: On-disk copy of SSTable files for a keyspace/table at a point in time. Stored under `data/<keyspace>/<table>/snapshots/<snapshot_name>`. You run it when you want a full point-in-time backup; DSE creates the copy on the node (hard-links or copies). Snapshots stay on the node unless you copy them off yourself.
- **Incremental backup**: DSE tracks which flushed SSTables (and optionally commit logs) are new or changed since the last backup so you can copy only those files off the node. DSE does **not** copy files for you—it marks which files need to be backed up; your own process or scripts copy them. Use it for ongoing backups so each run backs up only deltas.
- **What is actually in each:**
   - **Snapshot** = a copy of **all SSTable files** for the keyspace/table(s) you snapshot, as they exist on that node when you run it (full set of flushed data; no commit log). 
   - **Incremental backup** = **only the SSTable files (and optionally commit log segments) that are new or changed since your last backup run**—each run is a delta (new flushes/compactions). 
   - Restore = **base** (full snapshot or full backup) **+** apply **all incremental copies in order**.  
- **Restore**: Replace data directories with snapshot/incremental files and restart (or use **sstableloader** to load into a new cluster).
   - For a single node: shell into the container (`./scripts/shell.sh` or `./scripts/shell.sh <service>`), run `dse cassandra-stop`, restore that node’s backup into its data directory, then run `dse cassandra` to start DSE again (or restart the container).
   - **In a cluster with multiple nodes**: each node has its own data and its own backup. Restore **each node from the backup that was taken on that node** (or from a backup of a replica if you are replacing a failed node). Do not mix backups from different nodes. 

Typical approaches:
   1. **Full-cluster restore** — stop all nodes, restore each node’s data directory from that node’s backup (snapshot + incremental in order), then start all nodes (e.g. seed first, then others).
   2. **Single-node restore** — stop only that node, restore its data from its backup, restart it; the rest of the cluster stays up.
   3. **Restore to a new cluster** — use **sstableloader** to load SSTables from backup into a new or existing cluster without replacing data dirs; useful for cloning or migrating. See [DSE 6.8 Backup and Restore](https://docs.datastax.com/en/dse/6.8/managing/in-memory/backup-restore-data.html) or [DSE 6.9 Backup and Restore](https://docs.datastax.com/en/dse/6.9/managing/in-memory/backup-restore-data.html) for step-by-step procedures.

## Prerequisites in the Lab

- Cluster up (e.g. `./scripts/up-cluster.sh`).
- Keyspace with data (e.g. `training` from [03 – Environment](03-environment.md)).

## Snapshot (Full Backup)

**Snapshot is per-node.** Each node stores only the data for the token ranges it owns. For a **full-cluster backup**, run snapshot (and list/clear) on **every node**—e.g. seed, dse-node-1, dse-node-2. The examples below show the seed; use `./scripts/nodetool-node.sh <service>` for the other nodes.

### Create a snapshot

Creates a snapshot named `before_repair_lab` for the whole `training` keyspace **on the seed**:

```bash
./scripts/nodetool.sh snapshot training -t before_repair_lab
```

**Full-cluster snapshot** (run on each node):

```bash
./scripts/nodetool.sh snapshot training -t before_repair_lab
./scripts/nodetool-node.sh dse-node-1 snapshot training -t before_repair_lab
./scripts/nodetool-node.sh dse-node-2 snapshot training -t before_repair_lab
```

List snapshots on the seed (or use `nodetool-node.sh dse-node-1 listsnapshots`, etc.):

```bash
./scripts/nodetool.sh listsnapshots
```

Snapshot files live inside each container under `/var/lib/cassandra/data/.../snapshots/before_repair_lab/`. To list snapshot paths, open a shell in the seed container and run the find (use `./scripts/shell.sh dse-node-1` or `dse-node-2` for other nodes):

```bash
./scripts/shell.sh
# Then inside the container:
find /var/lib/cassandra -type d -name "snapshots" 2>/dev/null
```

### Snapshot all keyspaces

On the seed (repeat on other nodes for full-cluster):

```bash
./scripts/nodetool.sh snapshot -t full_backup_$(date +%Y%m%d)
```

### Clear old snapshots

Snapshots are not deleted automatically. Remove a specific tag or all snapshots for a keyspace to free disk. Run on **each node** if you created snapshots on all nodes:

```bash
./scripts/nodetool.sh clearsnapshot training -t before_repair_lab
./scripts/nodetool-node.sh dse-node-1 clearsnapshot training -t before_repair_lab
./scripts/nodetool-node.sh dse-node-2 clearsnapshot training -t before_repair_lab
# Or clear all snapshots for the keyspace (per node)
./scripts/nodetool.sh clearsnapshot training
```

## Incremental Backup

- **Incremental backup** in DSE means: after each flush, SSTables are retained (not deleted) so an external process can copy them. You still need to copy the files (e.g. to S3 or NFS) and manage retention.
- Enable per keyspace or cluster-wide.

### Enable incremental backup (cluster-wide)

In `cassandra.yaml` (at `/opt/dse/resources/cassandra/conf/cassandra.yaml`), set `incremental_backup: true`. In Docker you’d typically set this via a custom config or env. For the lab you can enable it by running (if your image supports it) or by documenting it:

- Default in DSE 6.8/6.9 configs is `false`. When enabled, DSE keeps flushed SSTables that would otherwise be removed by compaction until they are backed up or aged out by your process.

Enable via nodetool (if available in your version):

```bash
./scripts/nodetool.sh enablebackup
```

Check status:

```bash
./scripts/nodetool.sh statusbackup
```

Disable:

```bash
./scripts/nodetool.sh disablebackup
```

(Exact commands may vary by DSE version; refer to [DSE 6.8 Backup and Restore](https://docs.datastax.com/en/dse/6.8/managing/in-memory/backup-restore-data.html) or [DSE 6.9 Backup and Restore](https://docs.datastax.com/en/dse/6.9/managing/in-memory/backup-restore-data.html).)

## Cleanup Before Snapshot (Best Practice)

If you added or removed nodes and want a clean backup: run **cleanup** on each node so that node no longer holds data for token ranges it no longer owns. Then take the snapshot.

```bash
# On seed, then on each other node (from repo root)
./scripts/nodetool.sh cleanup
./scripts/nodetool-node.sh dse-node-1 cleanup
./scripts/nodetool-node.sh dse-node-2 cleanup
```

Then create the snapshot as above.

## Restore (High Level)

1. **Full restore from snapshot** (single node or full cluster):
   - Stop DSE on the node(s). In this Compose lab there is no data on the host—shell into the container with `./scripts/shell.sh` (or `./scripts/shell.sh dse-node-1` for another node), then run `dse cassandra-stop`.
   - Replace the keyspace/table data directories with the snapshot (and any incremental) files, preserving directory layout (paths are under `/var/lib/cassandra/data/` in the container).
   - Start DSE again: inside the container run `dse cassandra`, or exit and restart the container.
2. **Restore into a new cluster**: use **sstableloader** to load snapshot SSTables into a new cluster (same topology/schema). See [DSE 6.8 sstableloader](https://docs.datastax.com/en/dse/6.8/managing/tools/sstableloader/) or [DSE 6.9 sstableloader](https://docs.datastax.com/en/dse/6.9/managing/tools/sstableloader/) documentation.

💡 **DSE 6.9 Performance Note**: Restore operations benefit from zero-copy streaming improvements in DSE 6.9, making data loading faster than in DSE 6.8.

For the lab, creating and listing snapshots and running cleanup is enough; full restore can be read in the docs and practiced in a dedicated exercise.

## Hands-On end-to-end Checklist

1. Create snapshot: `./scripts/nodetool.sh snapshot training -t lab_backup`
2. List: `./scripts/nodetool.sh listsnapshots`
3. (Optional) Enable incremental backup and run `./scripts/nodetool.sh statusbackup`
4. Clear snapshot: `./scripts/nodetool.sh clearsnapshot training -t lab_backup`
5. Run `./scripts/nodetool.sh cleanup` on the seed and `./scripts/nodetool-node.sh dse-node-1 cleanup` and `./scripts/nodetool-node.sh dse-node-2 cleanup` on the other nodes, then take another snapshot
6. **Restore procedure** (optional in lab): To restore from a snapshot—**per node**—stop DSE **inside the container** (data lives in the container, not on the host). Open a shell with `./scripts/shell.sh` (or `./scripts/shell.sh dse-node-1` for another node), then run `dse cassandra-stop`, copy the snapshot files from `/var/lib/cassandra/data/<keyspace>/<table>/snapshots/<tag>/` into the live keyspace/table data path (or replace that table’s directory), then run `dse cassandra` to start DSE again (or exit and restart the container). For full-cluster restore, repeat for each node from that node’s backup. See the Restore section above and [DSE 6.8 Backup and Restore](https://docs.datastax.com/en/dse/6.8/managing/in-memory/backup-restore-data.html) or [DSE 6.9 Backup and Restore](https://docs.datastax.com/en/dse/6.9/managing/in-memory/backup-restore-data.html).

## Next

Go to [07 – Repair & Maintenance](07-repair-maintenance.md) for anti-entropy repair and cleanup.
