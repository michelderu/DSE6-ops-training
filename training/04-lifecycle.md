# Module 04 — Cluster Lifecycle

Manage the DSE 6.8/6.9 cluster: start, stop, check status, and understand scaling in the Docker Compose environment.

💡 **DSE 6.9 Note**: Node addition and bootstrap operations are significantly faster in DSE 6.9 due to zero-copy streaming improvements (up to 4x faster than DSE 6.8).

## 🎯 Goals

- 🚀 Start and stop the cluster and individual services
- ✅ Check node and cluster status with nodetool
- 📈 Understand bootstrap order and scaling

## 🚀 Starting the Cluster

✅ **Recommended (script):**

```bash
./scripts/up-cluster.sh
```

💡 This starts the seed, waits until it is UN, then starts the two extra nodes (3-node cluster).

📝 **Manual (step by step):**

```bash
# 1. Seed only
docker-compose up -d dse-seed
# Or: docker compose up -d dse-seed

# 2. Wait until seed is UN
./scripts/nodetool.sh status
# When you see UN for the seed, continue.

# 3. Add 2 more nodes
docker-compose up -d dse-node-1
# Or: docker compose up -d dse-node-1
```

## 🛑 Stopping the Cluster

**Stop all services (containers):**

```bash
docker-compose down
# Or: docker compose down
```

💾 **Data preservation**: Data in `./data/` (seed, node1, node2) is preserved. To wipe data, remove the `data/` directory after stopping the cluster.

**Stop only DSE nodes** (e.g. keep other containers if you had any):

```bash
docker-compose stop dse-node-1 dse-node-2 dse-seed
# Or: docker compose stop ...
```

## ✅ Checking Status

### 📊 Node and cluster status

```bash
./scripts/nodetool.sh status
```

**Output columns:**
- **Address**: Node IP (or hostname).
- **State**: **UN** = Up Normal, **UJ** = Up Joining, **DN** = Down Normal, **UL** = Up Leaving, etc.
- **Load**: Data size on the node.
- **Tokens**: Number of vnode tokens (e.g. 256).
- **Owns**: Fraction of the ring (e.g. 33.3% for 3 nodes).
- **Host ID**: Unique ID for the node.

✅ **Expected**: All nodes should show **UN** when the cluster is healthy.

### 🔍 Describe cluster and datacenter

```bash
./scripts/cqlsh.sh -e "DESCRIBE CLUSTER;"
./scripts/cqlsh.sh -e "DESCRIBE KEYSPACE system;"
```

### 🐳 Container status

From repo root: `docker-compose ps` (Or: `docker compose ps`) to see running containers (dse-seed, dse-node-1, dse-node-2).

## 🔧 Running nodetool on a Specific Node

From repo root:

```bash
# Seed
./scripts/nodetool.sh status

# One of the other nodes (dse-node-1 or dse-node-2)
./scripts/nodetool-node.sh dse-node-1 status
```

💡 `nodetool status` run on any node shows the same ring view; the cluster is shared.

## 📈 Scaling Nodes (Lab)

Our Compose file defines a single **node** service that you scale:

**Current**: dse-seed + dse-node-1 + dse-node-2 = 3 nodes.

**Fewer nodes** (e.g. 2 total): stop one node container (e.g. `docker-compose stop dse-node-2` or `docker compose stop dse-node-2`) and run `nodetool decommission` or `nodetool removenode` from another node (see DSE docs).

**More nodes**: add more services (dse-node-3, dse-node-4, …) in `docker-compose.yml` with their own `./data/node3`, etc., and `SEEDS: dse-seed`. Start them after the seed is healthy.

⚠️ **Important**: In production, run only one DSE node per physical host. In this lab we run multiple nodes on one host for convenience only.

## 🔄 Bootstrap Order

New nodes must discover the cluster via seeds. In Compose:

1. **Seed** must be up and **UN** first.
2. Other nodes use `SEEDS=dse-seed` and `depends_on: dse-seed (healthy)`.
3. The `up-cluster.sh` script enforces this order.

⚠️ **Note**: If you start everything with `docker-compose up -d` (or `docker compose up -d`) without the script, the seed might not be ready when other nodes start; they can retry, but may log bootstrap errors until the seed is healthy.

## 🔄 Restarting a Single Node

**Seed:**

```bash
docker-compose restart dse-seed
# Or: docker compose restart dse-seed
```

**One of the other nodes (e.g. dse-node-1):**

```bash
docker-compose restart dse-node-1
# Or: docker compose restart dse-node-1
```

💡 After a restart, run `nodetool status` until the node is UN again.

## 📝 Summary

| Task | Command |
|------|--------|
| 🚀 Start full cluster | `./scripts/up-cluster.sh` |
| 🛑 Stop all | `docker-compose down` (Or: `docker compose down`) |
| ✅ Node status | `./scripts/nodetool.sh status` |
| 🐳 Container list | `docker-compose ps` (Or: `docker compose ps`) |
| 🔄 Restart seed | `docker-compose restart dse-seed` (Or: `docker compose restart dse-seed`) |

## 🚀 Next

Go to [05 – Monitoring](05-monitoring.md) for nodetool commands and monitoring.
