# DSE 6.8/6.9 Operations Training — Quick Reference

A quick reference guide for common DSE operations commands used throughout the training.

## 🚀 Cluster Management

### Start/Stop Cluster

```bash
# Start cluster (seed first, then nodes)
./scripts/up-cluster.sh

# Stop all containers
docker-compose down
# Or: docker compose down

# Stop specific node
docker-compose stop dse-node-1

# Restart specific node
docker-compose restart dse-node-1

# Reset cluster (stop, remove data, optionally restart)
./scripts/reset-cluster.sh
./scripts/reset-cluster.sh --restart  # Reset and restart
```

### Check Status

```bash
# Cluster status (ring view)
./scripts/nodetool.sh status

# Node info (heap, load, uptime)
./scripts/nodetool.sh info

# Cluster description
./scripts/nodetool.sh describecluster

# Ring view (token ranges)
./scripts/nodetool.sh ring

# Run on specific node
./scripts/nodetool-node.sh dse-node-1 status
```

## 📊 Monitoring

### Node Metrics

```bash
# Node summary (heap, load, cache)
./scripts/nodetool.sh info

# Table statistics
./scripts/nodetool.sh tablestats training
./scripts/nodetool.sh tablestats training sample

# Table histograms (latency, throughput)
./scripts/nodetool.sh tablehistograms training sample

# Thread pool stats
./scripts/nodetool.sh tpstats

# Compaction stats
./scripts/nodetool.sh compactionstats

# Network stats (streaming, connections)
./scripts/nodetool.sh netstats

# Gossip info
./scripts/nodetool.sh gossipinfo
```

### Logs

```bash
# Follow all logs
./scripts/logs.sh

# Follow specific node logs
./scripts/logs.sh dse-seed
./scripts/logs.sh dse-node-1

# Last N lines
./scripts/logs.sh dse-seed --tail 50

# Inside container
./scripts/shell.sh
tail -f /var/log/cassandra/system.log
```

## 💾 Backup & Restore

### Snapshots

```bash
# Create snapshot
./scripts/nodetool.sh snapshot training

# Create snapshot with name
./scripts/nodetool.sh snapshot -t backup-2024-01-15 training

# List snapshots
./scripts/nodetool.sh listsnapshots

# Clear snapshot
./scripts/nodetool.sh clearsnapshot -t backup-2024-01-15 training
```

### Incremental Backup

```bash
# Enable incremental backup (in cassandra.yaml)
incremental_backup: true

# After enabling, restart node
docker-compose restart dse-seed
```

## 🔧 Repair & Maintenance

### Repair

```bash
# Primary-only repair (recommended for routine)
./scripts/nodetool.sh repair -pr

# Primary-only incremental repair
./scripts/nodetool.sh repair -pr -inc

# Repair specific keyspace
./scripts/nodetool.sh repair training -pr

# Repair specific table
./scripts/nodetool.sh repair training sample -pr

# Local datacenter only
./scripts/nodetool.sh repair -pr -local
```

### Cleanup

```bash
# Cleanup (run on each node after topology changes)
./scripts/nodetool.sh cleanup
./scripts/nodetool-node.sh dse-node-1 cleanup
./scripts/nodetool-node.sh dse-node-2 cleanup
```

### Compaction

```bash
# Check compaction status
./scripts/nodetool.sh compactionstats

# Get compaction throughput
./scripts/nodetool.sh getcompactionthroughput

# Set compaction throughput (MB/s)
./scripts/nodetool.sh setcompactionthroughput 32

# Force compaction (use with care)
./scripts/nodetool.sh compact training sample
```

## 🔐 DSE Configuration

### Configuration Encryption

```bash
# Encrypt a password
./scripts/dsetool.sh encryptconfigvalue "myPassword123"

# Create system key
./scripts/dsetool.sh createsystemkey system_key

# DSE status
./scripts/dsetool.sh status

# Run on specific node
./scripts/dsetool-node.sh dse-node-1 status
```

## 📝 CQL Operations

### Connect to CQL

```bash
# Interactive cqlsh
./scripts/cqlsh.sh

# Execute single command
./scripts/cqlsh.sh -e "DESCRIBE KEYSPACES"

# Execute file
./scripts/cqlsh.sh -f training/labs/sample-keyspace.cql
```

### Common CQL Commands

```cql
-- Describe cluster
DESCRIBE CLUSTER;

-- List keyspaces
DESCRIBE KEYSPACES;

-- Describe keyspace
DESCRIBE KEYSPACE training;

-- Describe table
DESCRIBE TABLE training.sample;

-- Set consistency level
CONSISTENCY QUORUM;
CONSISTENCY ONE;
CONSISTENCY ALL;

-- Check current consistency
CONSISTENCY;
```

## 🐚 Container Access

### Shell Access

```bash
# Shell on seed node
./scripts/shell.sh

# Shell on specific node
./scripts/shell.sh dse-node-1
./scripts/shell.sh dse-node-2
```

### Container Management

```bash
# List containers
docker-compose ps
# Or: docker compose ps

# View container logs
docker-compose logs dse-seed
docker-compose logs --tail 50 dse-seed

# Execute command in container
docker-compose exec dse-seed nodetool status
```

## 🔍 Troubleshooting

### Common Checks

```bash
# Check cluster status
./scripts/nodetool.sh status

# Check node info (heap, load)
./scripts/nodetool.sh info

# Check gossip
./scripts/nodetool.sh gossipinfo

# Check network connections
./scripts/nodetool.sh netstats

# Check logs
./scripts/logs.sh dse-seed --tail 100
```

### Container Health

```bash
# Check container status
docker-compose ps

# Check container health
docker inspect dse-seed | grep -A 10 Health

# Restart unhealthy container
docker-compose restart dse-seed
```

## 📁 Important Paths (Inside Container)

| Purpose | Path |
|---------|------|
| Config | `/opt/dse/resources/cassandra/conf/cassandra.yaml` |
| DSE Config | `/opt/dse/resources/dse/conf/dse.yaml` |
| System Log | `/var/log/cassandra/system.log` |
| Debug Log | `/var/log/cassandra/debug.log` |
| Data Directory | `/var/lib/cassandra/data/` |
| Snapshots | `/var/lib/cassandra/data/<keyspace>/<table>/snapshots/` |
| Commit Log | `/var/lib/cassandra/commitlog/` |
| Hints | `/var/lib/cassandra/hints/` |

## 🎯 Consistency Levels

| Level | Description | Use Case |
|-------|-------------|----------|
| `ONE` | One replica responds | Fast reads, eventual consistency |
| `QUORUM` | Majority of replicas | Balanced (recommended for RF=3) |
| `ALL` | All replicas respond | Strongest consistency, slowest |
| `LOCAL_ONE` | One local replica | Multi-DC, fast |
| `LOCAL_QUORUM` | Majority in local DC | Multi-DC, balanced |

## 🔗 Ports Reference

| Port | Purpose |
|------|---------|
| `9042` | CQL native protocol |
| `9160` | Thrift (legacy) |
| `7000` | Internode (gossip, streaming) |
| `7199` | JMX (nodetool, monitoring) |

## ⚡ Quick Tips

- **Always run scripts from repo root**: `./scripts/nodetool.sh status`
- **Check status before operations**: `./scripts/nodetool.sh status`
- **Use `-pr` for routine repairs**: Primary-only repair is faster
- **Monitor during operations**: Use `netstats` and `compactionstats`
- **Check logs for errors**: `./scripts/logs.sh dse-seed --tail 50`
- **Reset cleanly**: `./scripts/reset-cluster.sh` before starting fresh

## 📚 Module Reference

| Module | Focus | Key Commands |
|--------|-------|--------------|
| [01 – Database Architecture](01-database-architecture.md) | Internal concepts | - |
| [02 – Cluster Architecture](02-cluster-architecture.md) | Topology, replication | `DESCRIBE CLUSTER` |
| [03 – Environment](03-environment.md) | Setup | `./scripts/up-cluster.sh` |
| [04 – Lifecycle](04-lifecycle.md) | Start/stop/scale | `nodetool status` |
| [05 – Monitoring](05-monitoring.md) | Health checks | `nodetool info`, `tpstats` |
| [06 – Backup & Restore](06-backup-restore.md) | Snapshots | `nodetool snapshot` |
| [07 – Repair & Maintenance](07-repair-maintenance.md) | Repair, cleanup | `nodetool repair -pr` |
| [08 – Troubleshooting](08-troubleshooting.md) | Debug issues | `gossipinfo`, logs |
| [09 – DSE Config](09-dse-config.md) | Configuration | `dsetool encryptconfigvalue` |

---

💡 **Tip**: Keep this reference open while working through the training modules!
