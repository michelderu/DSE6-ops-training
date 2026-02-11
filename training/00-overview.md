# DSE 6.8/6.9 Operations Training — Overview

This training is designed for **operations teams** who will run and maintain DataStax Enterprise (DSE) 6.8 and 6.9 clusters. It uses a **local Docker or Colima** environment with Compose so you can complete all modules on your laptop with minimal setup.

## 🎯 Objectives

By the end of this training you will be able to:

- ✅ Bring up and tear down a DSE 6.8/6.9 cluster with Docker or Colima Compose
- 🔍 Explain DSE 6.8/6.9 architecture (nodes, datacenters, replication, consistency)
- ⚙️ Perform day-to-day operations: start/stop, status, add/remove nodes
- 📊 Monitor the cluster with **nodetool** (and JMX/logs)
- 💾 Run **backup** (snapshots, incremental) and **restore**
- 🔧 Schedule and interpret **repair** (anti-entropy)
- 🐛 Apply basic **security** and **troubleshooting** practices

## 📋 Prerequisites

**Note**: No prior Cassandra or DSE experience is required; concepts are introduced as needed.

- 🐳 **Docker** (Engine + Compose: `docker-compose` or `docker compose`) or **Colima** (provides Docker; run `colima start`, then scripts use compose). Set `CONTAINER_RUNTIME=docker` or `CONTAINER_RUNTIME=colima` in `.env` so the scripts use the right commands.
  - **Apple Silicon**: DSE images are `linux/amd64` (x86_64). Use Colima with Rosetta: `colima start --arch aarch64 --vm-type=vz --vz-rosetta --cpu 8 --memory 16` (see [03 – Environment](03-environment.md) for details).
- 💻 **4 GB+ RAM** for the host (8 GB recommended for 3-node cluster)
- 💿 **Disk**: a few GB free for images and data
- ⌨️ Basic familiarity with the command line and YAML

## 📚 Training Structure

| Module | Topic | Focus |
|--------|--------|--------|
| [01 – Database Architecture](01-database-architecture.md) 🔍 | Gossip, storage engine, reads/writes, compaction | How Cassandra works internally |
| [02 – Cluster Architecture](02-cluster-architecture.md) 🏗️ | Nodes, replication, consistency | How DSE works |
| [03 – Environment](03-environment.md) 🐳 | Docker or Colima Compose, bring up cluster | Get the lab running |
| [04 – Lifecycle](04-lifecycle.md) ⚙️ | Start, stop, scale, status | Day-to-day control |
| [05 – Monitoring](05-monitoring.md) 📊 | nodetool, JMX, logs | Health and performance |
| [06 – Backup & Restore](06-backup-restore.md) 💾 | Snapshots, incremental backup | Data protection |
| [07 – Repair & Maintenance](07-repair-maintenance.md) 🔧 | Anti-entropy repair, cleanup | Consistency and disk |
| [08 – Troubleshooting](08-troubleshooting.md) 🐛 | Logs, common failures, recovery | When things go wrong |
| [09 – DSE Config](09-dse-config.md) 🔐 | dsetool, configuration encryption | DSE-specific configuration tasks |
| [10 – Advanced Operations](10-advanced-operations.md) 🚫 | Decommission, removenode, tokens | Advanced cluster operations |
| [11 – Production Readiness](11-production-readiness.md) 🏭 | Production checklist, security, monitoring | Preparing for production |

**Each module includes** concepts, commands, and hands-on steps you can run in the Docker or Colima environment.

## 🧪 Additional Lab Exercises

- **[DSE 6 Features Lab](labs/dse6-features.md)**: Hands-on exercises exploring DSE 6.8/6.9 specific features and performance improvements
- **[Troubleshooting Scenarios](labs/troubleshooting-scenarios.md)**: Practice troubleshooting common issues

## 🧪 Lab Environment Summary

- **Cluster**: 1 seed node + 2 additional nodes (3 nodes total)
- **Services**: DSE 6.8/6.9 (CQL 9042 on seed)
- **Access**: use `./scripts/cqlsh.sh`, `./scripts/nodetool.sh`, and `./scripts/dsetool.sh` (they use Docker or Colima based on `CONTAINER_RUNTIME` in `.env`)

## 🔄 DSE 6.8 vs 6.9

This training covers both DSE 6.8 and 6.9. Key differences:

- **DSE 6.9 improvements**: Zero-copy streaming provides up to 4x faster streaming, repair, and node operations compared to DSE 6.8
- **Compatibility**: DSE 6.9 is backward compatible with DSE 6.8
- **Upgrade path**: DSE 6.8 → DSE 6.9 (one node at a time, see upgrade documentation)
- **Features**: Most features are identical; DSE 6.9 focuses on performance improvements

💡 **Note**: When a feature or command differs between versions, it will be noted in the training materials.

## 🚀 How to Use This Training

1. **📖 Start here**: Read [01 – Database Architecture](01-database-architecture.md) to understand how Cassandra works internally (recommended before setting up the lab).
2. **🏗️ Then**: Continue to [02 – Cluster Architecture](02-cluster-architecture.md) to learn about DSE topology, replication, and consistency.
3. **🐳 Set up lab**: Go to [03 – Environment](03-environment.md) to bring up the cluster.
4. Work through modules in order; later modules assume you have completed earlier ones.
5. Run every command and exercise in your local Compose environment.
6. 📚 Use the [Official DSE 6.8 Docs](https://docs.datastax.com/en/dse/6.8/) and [DSE 6.9 Docs](https://docs.datastax.com/en/dse/6.9/) for deeper reference.

## ⚡ Quick Reference

**Common commands** you'll use throughout the training:

- **Start cluster**: `./scripts/up-cluster.sh` (from repo root; uses Docker or Colima per `.env`)
- **Stop all**: `docker-compose down` (Or: `docker compose down`) (Docker or Colima)
- **cqlsh**: `./scripts/cqlsh.sh`
- **nodetool**: `./scripts/nodetool.sh status`
- **dsetool**: `./scripts/dsetool.sh status` (DSE-specific tasks)
- **logs**: `./scripts/logs.sh dse-seed` (view logs)
- **reset**: `./scripts/reset-cluster.sh` (clean reset)
