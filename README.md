# DSE 6.8/6.9 Operations Training

A **comprehensive DataStax Enterprise 6.8 and 6.9 training** for operations teams, using a **local Docker or Colima** environment with Compose so you can run everything on your laptop with minimal setup.

## What’s Included

- 🐳 **Docker or Colima** Compose stack: 3-node DSE 6.8/6.9 cluster
- 📚 **Training modules** (concepts + hands-on): database architecture, cluster architecture, environment setup, lifecycle, monitoring, backup/restore, repair, troubleshooting  
- 🛠️ **Helper scripts**: bring up cluster in order, run `cqlsh`, `nodetool`, and `dsetool` on the seed (runtime chosen via `CONTAINER_RUNTIME`)  

## 📋 Prerequisites

- 🐳 **Docker** or **Colima**:
  - **Docker**: Docker Engine + Docker Compose (`docker-compose` or plugin `docker compose`)
  - **Colima**: Colima (provides Docker-compatible daemon; install with `brew install colima`). On **Apple Silicon (arm64)** start Colima with an x86_64 VM so the DSE image (linux/amd64) runs natively: `colima start --arch x86_64`. On Intel Macs: `colima start`.
- 💻 **4 GB+ RAM** for the host (8 GB recommended for 3-node cluster)
- 💿 A few GB free disk for images and data

## 🚀 Quick Start

```bash
# 1. Clone or open this repo
cd DSE-ops-training

# 2. (Optional) Copy and edit .env for runtime, image tags, or heap size
cp .env.example .env
# Use Colima: set CONTAINER_RUNTIME=colima in .env. On Apple Silicon: colima start --arch x86_64

# 3. Start the cluster (seed first, then 2 nodes)
./scripts/up-cluster.sh

# 4. Wait ~2 minutes, then check status
./scripts/nodetool.sh status

# 5. Connect to CQL
./scripts/cqlsh.sh
```

**Endpoint**: 🔌 **CQL**: `localhost:9042` (seed node)

## 📚 Training Curriculum

Start with **[training/00-overview.md](training/00-overview.md)** and follow the modules in order:

| Module | Topic | Focus |
|--------|--------|--------|
| [01 – Database Architecture](training/01-database-architecture.md) | Gossip, storage engine, reads/writes, compaction | How Cassandra works internally |
| [02 – Cluster Architecture](training/02-cluster-architecture.md) | Nodes, replication, consistency | How DSE works |
| [03 – Environment](training/03-environment.md) | Docker or Colima Compose, bring up cluster | Get the lab running |
| [04 – Lifecycle](training/04-lifecycle.md) | Start, stop, scale, status | Day-to-day control |
| [05 – Monitoring](training/05-monitoring.md) | nodetool, JMX, logs | Health and performance |
| [06 – Backup & Restore](training/06-backup-restore.md) | Snapshots, incremental backup | Data protection |
| [07 – Repair & Maintenance](training/07-repair-maintenance.md) | Anti-entropy repair, cleanup | Consistency and disk |
| [08 – Troubleshooting](training/08-troubleshooting.md) | Logs, common failures, recovery | When things go wrong |
| [09 – DSE Config](training/09-dse-config.md) | dsetool, configuration encryption | DSE-specific configuration tasks |
| [10 – Advanced Operations](training/10-advanced-operations.md) | Decommission, removenode, tokens | Advanced cluster operations |
| [11 – Production Readiness](training/11-production-readiness.md) | Production checklist, security, monitoring | Preparing for production |

💡 **Each module includes** concepts, commands, and hands-on steps you can run in the Docker or Colima environment.

## 🛠️ Scripts

| Script | Purpose |
|--------|--------|
| `scripts/up-cluster.sh` | 🚀 Start seed, wait for DSE readiness, then start 2 nodes (3-node cluster) |
| `scripts/cqlsh.sh` | 📝 Run `cqlsh` on the seed (e.g. `./scripts/cqlsh.sh -e "DESCRIBE KEYSPACES"`) |
| `scripts/nodetool.sh` | 📊 Run `nodetool` on the seed (e.g. `./scripts/nodetool.sh status`) |
| `scripts/nodetool-node.sh` | 🔧 Run `nodetool` on a specific node (e.g. `./scripts/nodetool-node.sh dse-node-1 status`) |
| `scripts/dsetool.sh` | 🔐 Run `dsetool` on the seed (e.g. `./scripts/dsetool.sh encryptconfigvalue "password"`) |
| `scripts/dsetool-node.sh` | 🔐 Run `dsetool` on a specific node (e.g. `./scripts/dsetool-node.sh dse-node-1 status`) |
| `scripts/logs.sh` | 📋 View logs easily (e.g. `./scripts/logs.sh dse-seed` or `./scripts/logs.sh dse-seed --tail 50`) |
| `scripts/reset-cluster.sh` | 🔄 Reset cluster (stop, remove data, optionally restart) |
| `scripts/shell.sh` | 🐚 Open an interactive shell in a container (e.g. `./scripts/shell.sh` or `./scripts/shell.sh dse-node-1`) |

💡 All scripts are intended to be run from the **repository root**.

## ⚙️ Configuration

- 🐳 **Runtime**: Set `CONTAINER_RUNTIME=docker` or `CONTAINER_RUNTIME=colima` in `.env`. Scripts use this to run `docker-compose` and `docker exec`.
- 🖼️ **Images**: Set `DSE_IMAGE` in `.env` (see `.env.example`). For DSE 6.8 use a 6.8.x tag, for DSE 6.9 use a 6.9.x tag from [Docker Hub](https://hub.docker.com/r/datastax/dse-server/tags) (e.g. `datastax/dse-server:6.8.62-ubi7` or `datastax/dse-server:6.9.18-ubi`).
- 🏗️ **Cluster**: `CLUSTER_NAME`, `DC` in `.env` (defaults: `DSE`, `DC1`).
- 💾 **Heap**: Limited to 1G for use on laptops.

## 🛑 Stopping and Cleaning Up

Stop the cluster:

```bash
docker-compose down
# Or: docker compose down
```

## ⚠️ Production Note

**Important**: This setup runs **multiple DSE nodes on one host** for training only. In production, run **one DSE node per physical host** to avoid a single point of failure. See [DataStax Docker recommended settings](https://docs.datastax.com/en/docker/managing/recommended-settings.html).

## 📚 References

- 📖 [DSE 6.8 Documentation](https://docs.datastax.com/en/dse/6.8/)
- 📖 [DSE 6.9 Documentation](https://docs.datastax.com/en/dse/6.9/)
- 🐳 [DataStax Docker Guide](https://docs.datastax.com/en/docker/)
- 🔄 [Upgrading DSE 6.8 to 6.9](https://docs.datastax.com/en/upgrading/datastax-enterprise/dse-68-to-69.html)
