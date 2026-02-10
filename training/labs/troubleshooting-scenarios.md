# Troubleshooting Scenarios — Intentionally Broken States

These scenarios present intentionally broken cluster states for you to diagnose and fix. Use them to practice troubleshooting skills learned in Module 08.

## 🎯 How to Use These Scenarios

1. **Read the scenario** and symptoms
2. **Diagnose** the problem using tools from Module 08
3. **Fix** the issue
4. **Verify** the cluster is healthy again

💡 **Tip**: Don't peek at the solutions until you've tried to diagnose yourself!

---

## Scenario 1: Node Won't Join 🟢 Beginner

### Setup

```bash
# Stop node-2
docker-compose stop dse-node-2

# Wait a moment, then check status
./scripts/nodetool.sh status
```

### Symptoms

- `dse-node-2` shows as **DN** (Down Normal) in `nodetool status`
- Other nodes are **UN** (Up Normal)
- Node-2 container is stopped

### Your Task

1. Diagnose why the node is down
2. Determine if it's a container issue or DSE issue
3. Restart the node
4. Verify it rejoins the cluster

### Diagnostic Steps (Try These)

```bash
# Check container status
docker-compose ps

# Check node status
./scripts/nodetool.sh status

# Check gossip
./scripts/nodetool.sh gossipinfo | grep dse-node-2

# Check logs (if container is running)
./scripts/logs.sh dse-node-2 --tail 50
```

### Solution

<details>
<summary>Click to reveal solution</summary>

```bash
# 1. Check container status
docker-compose ps
# Should show dse-node-2 as stopped

# 2. Restart the container
docker-compose start dse-node-2

# 3. Monitor it rejoining
watch -n 2 './scripts/nodetool.sh status'
# Should see UJ (Up Joining) then UN (Up Normal)

# 4. Verify it's fully joined
./scripts/nodetool.sh status
# All nodes should be UN
```

</details>

---

## Scenario 2: Seed Node Unreachable 🟡 Intermediate

### Setup

```bash
# Stop the seed node
docker-compose stop dse-seed

# Wait a moment
sleep 5

# Check status from another node
./scripts/nodetool-node.sh dse-node-1 status
```

### Symptoms

- Seed node shows as **DN** (Down Normal)
- Other nodes may show warnings about seed
- Gossip may show seed as unreachable
- Cluster may still function (if RF allows)

### Your Task

1. Diagnose the impact of seed being down
2. Check if other nodes can still communicate
3. Restart the seed
4. Verify cluster recovers

### Diagnostic Steps (Try These)

```bash
# Check status from different nodes
./scripts/nodetool-node.sh dse-node-1 status
./scripts/nodetool-node.sh dse-node-2 status

# Check gossip
./scripts/nodetool-node.sh dse-node-1 gossipinfo

# Check if CQL still works
./scripts/cqlsh.sh -e "DESCRIBE KEYSPACES"

# Check logs
./scripts/logs.sh dse-node-1 --tail 50
```

### Solution

<details>
<summary>Click to reveal solution</summary>

```bash
# 1. Verify seed is down
docker-compose ps
# dse-seed should be stopped

# 2. Check impact on other nodes
./scripts/nodetool-node.sh dse-node-1 status
# May show warnings but cluster should still function

# 3. Restart seed
docker-compose start dse-seed

# 4. Monitor seed rejoining
watch -n 2 './scripts/nodetool.sh status'
# Seed should go from DN to UJ to UN

# 5. Verify cluster is healthy
./scripts/nodetool.sh status
# All nodes should be UN
```

</details>

---

## Scenario 3: High Heap Usage 🟡 Intermediate

### Setup

```bash
# This scenario simulates high heap usage
# Check current heap usage
./scripts/nodetool.sh info | grep Heap
```

### Symptoms

- Heap usage is consistently above 80%
- GC pauses are frequent
- Node may be slow to respond
- Logs show GC warnings

### Your Task

1. Identify high heap usage
2. Determine if it's a configuration issue or workload issue
3. Check logs for GC activity
4. Propose solutions

### Diagnostic Steps (Try These)

```bash
# Check heap usage
./scripts/nodetool.sh info

# Check logs for GC
./scripts/logs.sh dse-seed | grep -i gc

# Check current JVM settings
./scripts/shell.sh
# Inside container:
cat /opt/dse/resources/cassandra/conf/jvm.options | grep -i heap
```

### Solution

<details>
<summary>Click to reveal solution</summary>

**Diagnosis:**
- Heap is near maximum (check `nodetool info`)
- GC logs show frequent pauses
- Node performance degraded

**Solutions:**
1. **Short-term**: Reduce load or restart node
2. **Long-term**: Increase heap size in `.env`:
   ```bash
   # Edit .env
   JVM_EXTRA_OPTS="-Xms2G -Xmx2G -Xmn1G"
   ```
3. **Restart node** with new heap:
   ```bash
   docker-compose restart dse-seed
   ```
4. **Monitor** heap usage after restart:
   ```bash
   ./scripts/nodetool.sh info | grep Heap
   ```

</details>

---

## Scenario 4: Disk Space Full 🔴 Advanced

### Setup

```bash
# Check disk usage
./scripts/shell.sh
# Inside container:
df -h /var/lib/cassandra
```

### Symptoms

- Writes fail with "No space left on device"
- Logs show disk full errors
- Snapshots may be consuming space
- Node may become unresponsive

### Your Task

1. Identify what's consuming disk space
2. Check for old snapshots
3. Free up space
4. Verify node recovers

### Diagnostic Steps (Try These)

```bash
# Check disk usage
./scripts/shell.sh
df -h /var/lib/cassandra

# List snapshots
./scripts/nodetool.sh listsnapshots

# Check data directory sizes
./scripts/shell.sh
du -sh /var/lib/cassandra/data/*

# Check commit log size
du -sh /var/lib/cassandra/commitlog/*
```

### Solution

<details>
<summary>Click to reveal solution</summary>

```bash
# 1. Check what's using space
./scripts/shell.sh
df -h /var/lib/cassandra
du -sh /var/lib/cassandra/data/*

# 2. List snapshots
./scripts/nodetool.sh listsnapshots

# 3. Clear old snapshots
./scripts/nodetool.sh clearsnapshot training -t <old-snapshot-name>

# Or clear all snapshots for a keyspace
./scripts/nodetool.sh clearsnapshot training

# 4. Check commit log (if large)
# Commit logs are rotated automatically, but check:
du -sh /var/lib/cassandra/commitlog/*

# 5. Verify space freed
df -h /var/lib/cassandra

# 6. Restart node if needed
docker-compose restart dse-seed
```

</details>

---

## Scenario 5: Repair Hanging 🔴 Advanced

### Setup

```bash
# Start a repair
./scripts/nodetool.sh repair training -pr

# Let it run for a bit, then check status
./scripts/nodetool.sh netstats
```

### Symptoms

- Repair started but seems stuck
- No progress in netstats
- Compaction stats show activity but repair doesn't complete
- Logs may show timeouts

### Your Task

1. Diagnose why repair is hanging
2. Check for blocking conditions
3. Determine if repair should be cancelled or allowed to continue
4. Resolve the issue

### Diagnostic Steps (Try These)

```bash
# Check repair progress
./scripts/nodetool.sh netstats

# Check compaction stats
./scripts/nodetool.sh compactionstats

# Check logs for errors
./scripts/logs.sh dse-seed --tail 100 | grep -i repair

# Check node status
./scripts/nodetool.sh status

# Check gossip
./scripts/nodetool.sh gossipinfo
```

### Solution

<details>
<summary>Click to reveal solution</summary>

**Common causes:**

1. **Replica node is down**: Repair waits for all replicas
   ```bash
   # Check if all replicas are up
   ./scripts/nodetool.sh status
   # If a replica is DN, bring it up or use repair options
   ```

2. **Network issues**: Check connectivity
   ```bash
   ./scripts/nodetool.sh netstats
   # Look for connection errors
   ```

3. **Large data size**: Repair takes time
   ```bash
   # Check if streaming is happening
   ./scripts/nodetool.sh netstats
   # If streaming is active, repair is progressing (just slowly)
   ```

4. **Cancel and retry** (if needed):
   ```bash
   # Note: nodetool doesn't have a cancel repair command
   # You may need to restart the node (not recommended)
   # Better: Let it complete or fix underlying issue
   ```

**Best practice**: Monitor repair with `netstats` and `compactionstats`. If streaming is active, repair is progressing.

</details>

---

## Scenario 6: Schema Version Mismatch 🔴 Advanced

### Setup

This scenario requires modifying schema on one node only (advanced setup).

### Symptoms

- Schema changes don't propagate
- `nodetool describecluster` shows different schema versions
- CQL operations may fail
- Logs show schema version warnings

### Your Task

1. Identify schema version mismatch
2. Determine which node has wrong version
3. Fix the mismatch
4. Verify schema converges

### Diagnostic Steps (Try These)

```bash
# Check schema versions
./scripts/nodetool.sh describecluster

# Check on each node
./scripts/nodetool-node.sh dse-node-1 describecluster
./scripts/nodetool-node.sh dse-node-2 describecluster

# Check gossip for schema version
./scripts/nodetool.sh gossipinfo | grep schema

# Check logs
./scripts/logs.sh dse-seed | grep -i schema
```

### Solution

<details>
<summary>Click to reveal solution</summary>

**Diagnosis:**
- `describecluster` shows different schema versions
- Gossip shows schema version mismatch

**Solution:**

1. **Identify the node with wrong version**:
   ```bash
   ./scripts/nodetool.sh describecluster
   # Check each node
   ```

2. **Restart the node with wrong version**:
   ```bash
   docker-compose restart dse-node-1
   ```

3. **Monitor schema convergence**:
   ```bash
   watch -n 2 './scripts/nodetool.sh describecluster'
   # Schema versions should converge
   ```

4. **Verify**:
   ```bash
   ./scripts/nodetool.sh describecluster
   # All nodes should show same schema version
   ```

**Prevention**: Always run schema changes through a single coordinator. Don't modify schema files directly on nodes.

</details>

---

## 🎓 Learning Objectives

After completing these scenarios, you should be able to:

- ✅ Diagnose common cluster issues
- ✅ Use appropriate tools for troubleshooting
- ✅ Understand when to restart vs. when to wait
- ✅ Identify root causes vs. symptoms
- ✅ Apply fixes systematically
- ✅ Verify cluster health after fixes

---

## 📚 Related Modules

- [08 – Troubleshooting](08-troubleshooting.md) - Core troubleshooting concepts
- [05 – Monitoring](05-monitoring.md) - Monitoring tools and metrics
- [04 – Lifecycle](04-lifecycle.md) - Node lifecycle management

---

💡 **Tip**: Practice these scenarios regularly to build troubleshooting muscle memory!
