# DSE 6.8/6.9 Operations Training

A **comprehensive DataStax Enterprise 6.8 and 6.9 training** for operations teams, using a **local Docker or Colima** environment with Compose so you can run everything on your laptop with minimal setup.

## About DataStax Enterprise (DSE)

**DataStax Enterprise (DSE)** is a production-ready, distributed database built on Apache Cassandra®. DSE extends Cassandra with advanced features for enterprise workloads, including search, analytics, graph, and AI/ML capabilities.

### Core Database Features

- **Distributed Architecture**: Multi-datacenter, fault-tolerant design with automatic replication and sharding
- **Zero-Copy Streaming**: Up to 4x faster streaming, repair, and node operations compared to earlier versions
- **NodeSync**: Continuous background repair that eliminates manual repair scheduling for most workloads
- **Storage-Attached Indexing (SAI)**: High-performance secondary indexing with 43x better write throughput and 230x better latency than traditional secondary indexes

### Advanced Workloads

- **DSE Search**: Full-text search capabilities powered by Apache Solr
- **DSE Analytics**: Batch and streaming analytics with Apache Spark and AlwaysOn SQL
- **DSE Graph**: Graph database with Gremlin traversal language for relationship queries
- **Vector Search** (DSE 6.9): AI/ML workloads with vector embeddings and similarity search, powered by JVector engine (10x faster than Lucene-based search)

### Enterprise Features

- **DSE Advanced Security**: Role-based access control (RBAC), LDAP integration, Kerberos authentication, and transparent data encryption
- **Backup & Restore Service**: CQL-based automated backup and restore operations
- **Multi-Datacenter Support**: Built-in replication across datacenters with configurable consistency levels

### DSE 6.8 vs 6.9

This training covers both DSE 6.8 and 6.9. While both versions share core features like zero-copy streaming and NodeSync, **DSE 6.9** introduces significant new capabilities:

- **Vector Search**: Native support for vector embeddings and similarity search (requires Vector Add-on)
- **Enhanced SAI**: Text analyzers for semantic filtering and OR operator support in queries
- **Vector Indexing**: Native VECTOR data type indexing and querying

For a detailed feature comparison, see the **[DSE 6.8 vs 6.9 Functional Comparison](training/labs/dse6-features.md#dse-68-vs-69-functional-comparison)** table in the [DSE 6 Features Lab](training/labs/dse6-features.md).

## Managing DSE Operations: Self-Managed vs Mission Control

### This Training: Self-Managed Operations

This training teaches you how to **manage DSE operations yourself** using command-line tools (`nodetool`, `dsetool`, `cqlsh`) and understanding the underlying concepts. You'll learn:

- **Cluster lifecycle**: Starting, stopping, scaling nodes manually
- **Monitoring**: Using `nodetool` commands, JMX metrics, and log analysis
- **Maintenance**: Running repairs, cleanup, snapshots, and backups manually
- **Troubleshooting**: Diagnosing issues using logs, gossip info, and cluster status
- **Configuration**: Managing DSE configuration files and encryption

**When to use self-managed operations:**
- ✅ You need full control and visibility into every operation
- ✅ You want to understand how DSE works under the hood
- ✅ You have specific operational requirements or custom automation needs
- ✅ You're building internal tooling or integrating with existing systems
- ✅ You're learning DSE operations (this training!)

### DataStax Mission Control: Automated Operations Platform

**Mission Control** is DataStax's Kubernetes-based operations platform that **automates and simplifies** DSE cluster management. It provides:

- **Automated Lifecycle Management**: Provisioning, deployment, rolling restarts, upgrades
- **Advanced Operations**: Automated cleanup, rebuild, backup, and restore operations
- **Centralized Monitoring**: Unified observability across multiple clusters and datacenters
- **24/7 Automated Operations**: Same automation used for Astra DB
- **Multi-Cluster Management**: Orchestrate operations across regional cluster boundaries
- **Security**: Built-in authentication, authorization, and TLS encryption

**Deployment Options:**
- **Kubernetes**: Deploy on existing Kubernetes clusters (EKS, GKE, AKS, OpenShift, or any Kubernetes distribution)
- **VM/Bare Metal**: Deploy on virtual machines or bare-metal servers using an embedded Kubernetes cluster (simpler setup, less flexible scaling)

**When to use Mission Control:**
- ✅ You want to reduce operational overhead and manual tasks
- ✅ You manage multiple clusters or datacenters
- ✅ You need centralized monitoring and management
- ✅ You want automated operations with minimal manual intervention
- ✅ You prefer a UI-based approach for cluster management

### Comparison: Self-Managed vs Mission Control

| Aspect | Self-Managed (This Training) | Mission Control |
|--------|------------------------------|-----------------|
| **Control** | Full control over every operation | Automated operations with oversight |
| **Learning** | Deep understanding of DSE internals | Focus on high-level operations |
| **Complexity** | Manual execution of operations | Automated workflows |
| **Monitoring** | Command-line tools (`nodetool`, JMX) | Unified dashboard and metrics |
| **Multi-Cluster** | Manual coordination across clusters | Centralized multi-cluster management |
| **Setup Time** | Immediate (this training) | Requires Mission Control installation |
| **Customization** | Full flexibility for custom needs | Standardized automated workflows |
| **Troubleshooting** | Direct access to logs and tools | Integrated diagnostic tools |

**Best Practice**: Even if you plan to use Mission Control, understanding the underlying operations (as taught in this training) helps you:
- Make informed decisions about Mission Control configurations
- Troubleshoot issues when automation doesn't cover edge cases
- Understand what Mission Control is doing behind the scenes
- Build custom automation that complements Mission Control

For more information about Mission Control, see the [Mission Control Documentation](https://docs.datastax.com/en/mission-control/).

## What’s Included

- 🐳 **Docker or Colima** Compose stack: 3-node DSE 6.8/6.9 cluster
- 📚 **Training modules** (concepts + hands-on): database architecture, cluster architecture, environment setup, lifecycle, monitoring, backup/restore, repair, troubleshooting  
- 🛠️ **Helper scripts**: bring up cluster in order, run `cqlsh`, `nodetool`, and `dsetool` on the seed (runtime chosen via `CONTAINER_RUNTIME`)  

## 📋 Prerequisites

- 🐳 **Docker** or **Colima**:
  - **Docker**: Docker Engine + Docker Compose (`docker-compose` or plugin `docker compose`)
  - **Colima**: Colima (provides Docker-compatible daemon; install with `brew install colima`).
    - **Apple Silicon (arm64)**: DSE images are `linux/amd64` (x86_64). Start Colima with Rosetta translation: `colima start --arch aarch64 --vm-type=vz --vz-rosetta --cpu 6 --memory 12 --disk 60`. This runs an arm64 VM that uses Rosetta to translate x86_64 containers (faster than full x86_64 emulation).
    - **Intel Macs**: `colima start --cpu 6 --memory 12 --disk 60`
- 💻 **4 GB+ RAM** for the host (8 GB recommended for 3-node cluster)
- 💿 A few GB free disk for images and data

## 🚀 Quick Start

```bash
# 1. Clone or open this repo
cd DSE-ops-training

# 2. (Optional) Copy and edit .env for runtime, image tags, or heap size
cp .env.example .env
# Use Colima: set CONTAINER_RUNTIME=colima in .env.

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
| `scripts/logs.sh` | 📋 Tail `/var/log/cassandra/system.log` in container (e.g. `./scripts/logs.sh dse-seed` or `./scripts/logs.sh dse-seed --tail 50`) |
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
- 🎛️ [Mission Control Documentation](https://docs.datastax.com/en/mission-control/)
