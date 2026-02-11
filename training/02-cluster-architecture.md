# Module 02 — Cluster Architecture

Understand how DataStax Enterprise 6.8 and 6.9 are structured so you can operate and troubleshoot them effectively.

📌 **No cluster required:** This module is concepts and topology only. You will run cqlsh and try replication/consistency commands in [03 – Environment](03-environment.md) after the cluster is up.

## Goals

- Describe cluster, datacenter, rack, and node roles
- Explain replication and consistency in simple terms
- Relate these concepts to your Docker Compose cluster

## Cluster Topology

### Cluster → Datacenter → Rack → Node

- **Cluster**: One logical DSE deployment (one ring). Our lab cluster name is `DSE`.
- **Datacenter (DC)**: A group of nodes for replication and workload. Our lab has a single DC: `DC1`.
- **Rack**: A failure domain inside a DC (e.g. one rack = one cabinet). Used by the snitch for placement. Our lab uses `Rack1`.
- **Node**: A single DSE process (one machine or container). Each node holds a portion of the ring and replicas.

In Docker Compose we have **3 nodes** in **1 DC**, all in the same logical “rack” for simplicity.

### DSE topology vs cloud terms

When you run DSE in the cloud, the same hierarchy maps to familiar cloud concepts:

| DSE term | Meaning | Cloud equivalent (typical mapping) |
|----------|---------|------------------------------------|
| **Datacenter (DC)** | A group of nodes used for replication and workload; often a physical or logical site. | **Region** (e.g. AWS `us-east-1`, Azure `East US`, GCP `us-east1`) when one DC per region; or a **region** with one DC spanning multiple AZs. |
| **Rack** | A failure domain inside a DC (e.g. one cabinet). The snitch uses it to spread replicas. | **Availability Zone (AZ)** (e.g. AWS `us-east-1a`, Azure Zone 1, GCP `us-east1-b`) or **Fault Domain** — one rack per AZ is common. |
| **Node** | One DSE process (one machine). Each node owns part of the ring and replicas. | **Instance** / **VM** (e.g. AWS EC2 instance, Azure VM, GCP Compute Engine instance) or a **pod** when running on Kubernetes. |

💡 **Rule of thumb:** One **node** per **instance/VM**; put nodes in different **racks** (AZs) so one AZ failure doesn't take multiple replicas; use one **DC** per **region** (or per failure boundary) for multi-region setups.

### Seed Nodes

- **Seeds** are contact points for new nodes joining the cluster. They do not hold more data than other nodes.
- In our setup, **dse-seed** is the only seed. Other nodes use `SEEDS=dse-seed` to discover the cluster.
- Best practice: define 2–3 seeds per DC in production; for the lab, one seed is enough.

## Data Distribution: Partitioning and Replication

### Partition Key and Tokens

- Data is stored in **partitions**. Each partition is identified by a **partition key**.
- The partition key is hashed to a **token**. Tokens determine which node(s) own the partition.
- Each node is responsible for a range of tokens (the **ring**). With **vnodes** (default in DSE 6.8/6.9), each node has multiple small token ranges (e.g. 256 tokens per node).

**Added value of vnodes:** More even data distribution across the ring (no “hot” nodes from uneven manual token ranges). When you add or remove nodes, rebalancing streams many small ranges in parallel instead of a few large ones, so the cluster rebalances faster and no single node is overloaded. You also avoid manual token assignment: the cluster assigns vnodes automatically.

### Replication

- **Replication factor (RF)** is set per keyspace (e.g. `RF=3` in DC1 means three copies of each partition in DC1).
- Replicas are placed according to the **replication strategy** and **snitch**:
  - **NetworkTopologyStrategy**: You specify how many replicas per DC (e.g. `'DC1': 3`). Used for production and in our training keyspace.
  - **SimpleStrategy**: Single-DC only; you only set a number (e.g. RF=3). Good for dev/test.

In our 3-node cluster, `training` with `'DC1': 3` means every partition has one replica on each node.

**Where it’s defined in this training:**

In `./training/labs/sample-keyspace.cql`, replication is set when the keyspace is created: `CREATE KEYSPACE training WITH replication = { 'class': 'NetworkTopologyStrategy', 'DC1': 3 };`. That’s the `'DC1': 3` (RF=3 in DC1) and the strategy (NetworkTopologyStrategy).

Once the cluster is up (Module 03), you will run `DESCRIBE KEYSPACE training;` in cqlsh to see this definition; the keyspace is created in that module from `training/labs/sample-keyspace.cql`.

## ⚖️ Consistency Levels

- **Consistency level (CL)** defines how many replicas must respond for a read or write to be considered successful.

**Common levels:**
- ⚡ **ONE**: One replica (fast, less durable).
- ⚖️ **QUORUM**: Majority of replicas (e.g. 2 of 3). Good balance of safety and latency.
- 🔒 **ALL**: Every replica. Strongest, slowest.
- 🌐 **LOCAL_ONE** / **LOCAL_QUORUM**: Same but only in the local DC (multi-DC).

💡 **For a single-DC cluster with RF=3**: **QUORUM** (2 replicas) is a common choice for both reads and writes.

📝 **Trying it in the lab:** In cqlsh, consistency is set per session with `CONSISTENCY <level>;` (e.g. `CONSISTENCY ONE` or `CONSISTENCY QUORUM`); that level then applies to the next reads and writes until you change it. Once the cluster is up and the training keyspace exists ([03 – Environment](03-environment.md)), you will run these commands in cqlsh and try different consistency levels in [03 – Environment](03-environment.md) and [04 – Lifecycle](04-lifecycle.md).

## 🧩 Components in DSE 6.8/6.9

**Available components:**
- ✅ **Cassandra core**: CQL, storage engine, compaction, repair (what we use in this training).
- 🔍 **DSE Search** (Solr): Full-text search — optional (not covered in this training).
- 📊 **DSE Analytics** (Spark): Batch/streaming — optional (not covered in this training).
- 🕸️ **DSE Graph**: Graph model and Gremlin — optional (not covered in this training).
- 📊 **Storage-Attached Indexing (SAI)**: DSE 6.8+ feature for improved indexing performance (not covered in this training).

💡 **Our Docker Compose image** runs the **database (transactional)** profile only.

💡 **Performance improvements**: DSE 6.8 and 6.9 include zero-copy streaming capabilities, providing up to 4x faster streaming, making node recovery and addition much faster than earlier versions.

📚 **For deeper understanding of Cassandra internals**, see [01 – Database Architecture](01-database-architecture.md) which covers gossip, storage engine, reads/writes, compaction, and repair mechanisms in detail.

## 🔌 Ports (Reference)

| Port | Purpose |
|------|--------|
| 9042 | CQL native (clients) |
| 7000 | Internode (gossip, streaming) |
| 7199 | JMX (monitoring, nodetool) |

## 🧪 Relating This to Your Lab

**When you complete [03 – Environment](03-environment.md), your lab will have this configuration:**
- **Cluster**: `DSE` (from `CLUSTER_NAME` in Compose).
- **DC**: `DC1` (from `DC` in Compose).
- **Nodes**: `dse-seed` + 2 node containers; all in `DC1`, `Rack1`.
- **Seeds**: Only `dse-seed`; other nodes join via `SEEDS=dse-seed`.
- **Keyspace**: After you create it in Module 03, `training` will use `NetworkTopologyStrategy` and `'DC1': 3` — every row replicated to all 3 nodes.

## 🚀 Next

Go to [03 – Environment](03-environment.md) to set up your Docker or Colima lab environment, then continue to [04 – Lifecycle](04-lifecycle.md) to start, stop, and inspect the cluster and scale nodes.
