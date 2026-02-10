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

**DSE Backup & Restore: Snapshots vs. Incremental**

- **Snapshot (The "Base")**
  - **What is it?**  
    A snapshot is a point-in-time backup consisting of hard links to all SSTable files (immutable, flushed table data) for a specific keyspace or table on that node. This creates a consistent view of the persisted data at the exact instant the snapshot is taken, without interrupting database activity.
  - **How is it triggered?**  
    Snapshots are taken manually using the `nodetool snapshot` command.
  - **Where are they stored?**  
    Each snapshot is stored on the same node under `data/<keyspace>/<table>/snapshots/<snapshot_name>`.
  - **Management**  
    Snapshots are never removed automatically by DSE—you must manage them yourself (cleanup is done with `nodetool clearsnapshot` or by deleting the snapshot directories).

  - **What does a snapshot NOT include?**  
    Snapshots capture **only the SSTable files** present on disk at the time of the snapshot. They do **not** include:
    - Unflushed writes in the memtable (data that has not yet been written to SSTables—this is still only in memory or the commit log)
    - The active **commit log** (the commit log is not part of a snapshot and must be backed up separately if point-in-time recovery or full durability is required)
    - The contents of the `/backups/` directory (used by incremental backup)
    - Configuration files, schema history, user-defined functions, or any data outside of the main SSTables

    In short, a snapshot gives you a persistent, on-disk backup, but any data that hasn’t been flushed to disk as an SSTable prior to the snapshot is **not** included. For complete protection (especially to prevent data loss on sudden crashes), combine snapshots with commit log backups.

- **Incremental Backup (The "Delta")**
  - **What is it?**  
    Incremental backup is a mechanism that captures *just the new* SSTable files created after a full snapshot (the "base"). Every time DSE flushes a memtable to disk and creates a new SSTable, it also places a hard link to that file in the corresponding `backups` directory—*if* incremental backup is enabled. This allows you to capture only the data changes (the "delta") that occurred after your last snapshot, making it possible to restore the database to any point since that snapshot by combining the base snapshot and its incremental backups.
  - **How does it relate to snapshots?**  
    Snapshots capture the complete, point-in-time state of all SSTables as your base backup. Incremental backups then collect any new SSTables created after the snapshot, so you don't have to take a full backup every time. To restore to the present, you combine the last snapshot with all incremental SSTables created since.
  - **What is *not* included?**  
    Incremental backup only saves new SSTables and does *not* capture:
    - SSTables that existed before the last snapshot (those are in the snapshot, not increments)
    - The active commit log (needed for point-in-time crash recovery—you must copy or archive this separately)
    - Unflushed writes (data still in memtables)
    - Other node or schema data outside SSTables
  - **How is it triggered?**  
    This happens automatically—*but only if* you have `incremental_backups: true` set in `cassandra.yaml`.
  - **Where are they stored?**  
    Every incremental SSTable copy appears under `data/<keyspace>/<table>/backups/` on each node.
  - **"Last Backup" Logic:**  
    DSE does *not* know when you last copied incremental files—the `/backups/` folder accumulates SSTables until you or your backup script copies them somewhere else (and optionally clears the directory). "Files since last backup" means everything in `/backups/` since your last manual or scripted backup.

- **How Snapshots, Incrementals, and Commit Logs Work Together (Workflow and Backing Up In-Flight Data)**

  Snapshots and incremental backups *do not* capture unflushed/in-flight writes currently stored only in the commit log (i.e., data that is still in memory or has not yet been flushed to SSTables). To fully protect against data loss—including the most recent in-flight updates—you must **back up the commit log files** in addition to snapshots and incrementals.

  **Recommended backup workflow:**
  1. **Take a Full Snapshot:** This serves as your "base" recovery point (e.g., at time T₀). All SSTables flushed at this point are included.
  2. **Clear Incremental Backups:** Immediately after the snapshot, empty all `/backups/` folders on all nodes to remove any old incremental SSTable files.
  3. **Back Up Commit Logs:** As soon as the snapshot is taken, copy the contents of the commit log directory (`/var/lib/cassandra/commitlog/` in each node) to your backup location. Do this *before* restarting or flushing nodes, so all in-flight data is preserved.
  4. **Ongoing Incrementals and Commit Logs:** On a regular schedule (e.g., hourly), copy any new SSTables found in the `/backups/` folders as well as any new (not-yet-backed-up) commit log files from `/var/lib/cassandra/commitlog/` on each node to your backup location. After copying, you can clear the `/backups/` directories, but best practice is to **not** remove commit logs until they have been confirmed safely archived and applied after restoration.
  
  **Summary:**  
  - **Snapshot:** Point-in-time backup of flushed SSTables  
  - **Incremental:** Backup of newly created SSTables (deltas)  
  - **Commit logs:** Backup of all recent in-flight writes not yet flushed; required for full point-in-time recovery up to the most recent possible state.  

  > **Note:** To restore to the *exact* state of a node, restore the latest snapshot, apply all incremental SSTables, and then replay the backed-up commit logs.  

  > **IMPORTANT: Backups Are Node-Specific!**  
  > Each node in a multi-node cluster contains distinct data—do *not* restore a backup from Node A to Node B. Always restore each node using its own backups, or (if replacing a failed node) the backups from a replica of the same token range.

Granular approaches:
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
