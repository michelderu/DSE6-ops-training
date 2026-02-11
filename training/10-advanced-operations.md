# Module 10 — Advanced Operations

Perform advanced cluster operations including node decommissioning, removal, and token management. These operations are critical for cluster maintenance and scaling.

## 🎯 Goals

- 🚫 Decommission nodes gracefully from the cluster
- 🗑️ Remove failed nodes from the ring
- 🔄 Understand node failure and recovery (hinted handoff)
- 🔑 Understand token assignment and vnodes
- 📊 Monitor advanced operations
- ⚠️ Handle edge cases and recovery scenarios

## ⚠️ Important Warnings

**Before performing these operations:**

- ✅ **Backup first**: Always take snapshots before topology changes
- ✅ **Test in non-production**: Practice these operations in a test environment first
- ✅ **Plan downtime**: Some operations may impact cluster availability
- ✅ **Document steps**: Keep notes of what you're doing and why
- ✅ **Have rollback plan**: Know how to recover if something goes wrong

## 🚫 Node Decommissioning

**Decommissioning** gracefully removes a node from the cluster by:
1. Streaming its data to other replicas
2. Removing it from the ring
3. Stopping the DSE process

**When to decommission:**
- Permanently removing a node (not just restarting)
- Scaling down the cluster
- Replacing hardware
- Moving nodes to different datacenters

### Decommissioning Process

**Step 1: Verify cluster health**

```bash
# Check all nodes are healthy
./scripts/nodetool.sh status

# Verify the node you're removing is UN (Up Normal)
# If it's DN (Down Normal), use removenode instead (see below)
```

**Step 2: Take a snapshot (recommended)**

```bash
# Snapshot on the node being decommissioned
./scripts/nodetool-node.sh dse-node-1 snapshot -t before_decommission

# Also snapshot other nodes for safety
./scripts/nodetool.sh snapshot -t before_decommission
```

**Step 3: Run decommission**

```bash
# Run on the node being decommissioned
./scripts/nodetool-node.sh dse-node-1 decommission
```

**What happens:**
- The node streams its data to other replicas
- Progress can be monitored with `nodetool netstats`
- The node removes itself from the ring
- DSE process stops automatically when complete

**Step 4: Monitor progress**

```bash
# In separate terminals, monitor:
# Terminal 1: Watch streaming
./scripts/nodetool-node.sh dse-node-1 netstats

# Terminal 2: Watch ring status
./scripts/nodetool.sh status

# Terminal 3: Watch logs
./scripts/logs.sh dse-node-1
```

**Step 5: Verify completion**

```bash
# The node should no longer appear in the ring
./scripts/nodetool.sh status

# Verify data was streamed (check other nodes)
./scripts/nodetool.sh info
```

**Step 6: Stop and remove container**

```bash
# After decommission completes, stop the container
docker-compose stop dse-node-1

# Remove the container (optional)
docker-compose rm dse-node-1
```

### ⏱️ Decommission Duration

Decommission time depends on:
- **Data size**: More data = longer streaming time
- **Network speed**: Faster network = faster streaming
- **Cluster load**: High load may slow streaming
- **Number of replicas**: More replicas = more streaming destinations

**Estimate**: For a node with 100GB of data on a 1Gbps network, expect 15-30 minutes.

### ⚠️ Decommission Warnings

- **Don't interrupt**: Never kill the decommission process; let it complete
- **Monitor closely**: Watch for errors in logs
- **Check disk space**: Ensure destination nodes have space for streamed data
- **Network stability**: Unstable network can cause decommission to fail

## 🗑️ Removing Failed Nodes

**Removenode** removes a node that is already down or unreachable from the ring. Use this when:
- A node has failed and won't come back
- A node was decommissioned but didn't complete cleanly
- A node needs to be removed but is unreachable

### When to Use Removenode

- ✅ Node is **DN** (Down Normal) and won't recover
- ✅ Decommission started but failed/hung
- ✅ Node hardware failed
- ❌ **Don't use** if node is still running (use decommission instead)

### Removenode Process

**Step 1: Identify the node's Host ID**

```bash
# Get the Host ID from status (before it went down)
./scripts/nodetool.sh status

# Or check gossip info
./scripts/nodetool.sh gossipinfo | grep <node-ip-or-hostname>
```

**Step 2: Verify node is down**

```bash
# Confirm node is DN
./scripts/nodetool.sh status

# Try to connect (should fail)
./scripts/nodetool-node.sh dse-node-1 status
```

**Step 3: Run removenode**

```bash
# Run from ANY healthy node (not the failed node)
# Use the Host ID from step 1
./scripts/nodetool.sh removenode <host-id>

# Example:
./scripts/nodetool.sh removenode a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

**Alternative: Remove by status**

```bash
# If you see the node in status as DN, you can use:
./scripts/nodetool.sh removenode <status-output-line-number>

# Or remove by force (use with caution):
./scripts/nodetool.sh removenode <host-id> --force
```

**Step 4: Monitor removal**

```bash
# Watch the ring
./scripts/nodetool.sh status

# The node should disappear from the ring
# Other nodes will stream data to fill the gap
```

**Step 5: Run cleanup on remaining nodes**

After removenode, run cleanup on remaining nodes so they only keep data for ranges they own:

```bash
./scripts/nodetool.sh cleanup
./scripts/nodetool-node.sh dse-node-2 cleanup
```

### ⚠️ Removenode Warnings

- **Data loss risk**: If the removed node had the only copy of some data (RF=1), that data is lost
- **Streaming impact**: Other nodes will stream to fill the gap, increasing load
- **Irreversible**: Once removed, you can't "undo" removenode (must re-add node)
- **Verify RF**: Ensure replication factor is sufficient before removing nodes

## 🔑 Token Management and Vnodes

### Understanding Tokens

- **Token**: A number that determines which node owns a partition
- **Token range**: Range of tokens a node is responsible for
- **Vnodes**: Virtual nodes - each physical node has multiple token ranges (default: 256)

### Viewing Token Assignment

```bash
# View ring with tokens
./scripts/nodetool.sh ring

# View status with token count
./scripts/nodetool.sh status

# Describe cluster (shows partitioner)
./scripts/nodetool.sh describecluster
```

### Vnodes Benefits

- ✅ **Automatic balancing**: No manual token assignment needed
- ✅ **Faster rebalancing**: Many small ranges stream faster than few large ones
- ✅ **Better distribution**: More even data distribution
- ✅ **Easier scaling**: Adding/removing nodes is simpler

### Manual Token Assignment (Advanced)

**Note**: Manual tokens are rarely needed with vnodes (default). Only use for:
- Legacy clusters without vnodes
- Specific placement requirements
- Troubleshooting token distribution issues

**View current tokens:**

```bash
./scripts/nodetool.sh ring | grep <node-ip>
```

**Set tokens** (requires node restart):

1. Calculate tokens (use token calculator tools)
2. Set in `cassandra.yaml`: `initial_token: <token1>,<token2>,...`
3. Restart node

💡 **Recommendation**: Use vnodes (default) unless you have a specific requirement for manual tokens.

## 📊 Monitoring Advanced Operations

### During Decommission

```bash
# Monitor streaming progress
./scripts/nodetool-node.sh dse-node-1 netstats

# Check ring status
watch -n 2 './scripts/nodetool.sh status'

# Monitor logs
./scripts/logs.sh dse-node-1
```

### During Removenode

```bash
# Monitor ring (node should disappear)
./scripts/nodetool.sh status

# Check streaming on other nodes
./scripts/nodetool.sh netstats

# Monitor compaction (data rebalancing)
./scripts/nodetool.sh compactionstats
```

### Key Metrics to Watch

- **Streaming**: `netstats` shows active streaming
- **Load**: `info` shows data load per node (should rebalance)
- **Compaction**: `compactionstats` shows rebalancing activity
- **Ring state**: `status` shows node states and ownership

## 🧪 Hands-On Exercises

### 🟢 Beginner: Understanding the Ring

1. **View the ring structure:**
   ```bash
   ./scripts/nodetool.sh ring
   ```

2. **Check token distribution:**
   ```bash
   ./scripts/nodetool.sh status
   ```
   Note the "Tokens" column (should show 256 for vnodes).

3. **View cluster description:**
   ```bash
   ./scripts/nodetool.sh describecluster
   ```
   Note the partitioner (should be `Murmur3Partitioner`).

### 🟡 Intermediate: Simulate Node Removal

**⚠️ Warning**: This exercise simulates removal. Don't actually remove nodes unless you're ready to rebuild.

1. **Check current cluster state:**
   ```bash
   ./scripts/nodetool.sh status
   ```

2. **Stop a node** (simulate failure):
   ```bash
   docker-compose stop dse-node-2
   ```

3. **Observe status change:**
   ```bash
   ./scripts/nodetool.sh status
   ```
   Node should show as **DN** (Down Normal).

4. **Check gossip:**
   ```bash
   ./scripts/nodetool.sh gossipinfo | grep dse-node-2
   ```

5. **Restart the node:**
   ```bash
   docker-compose start dse-node-2
   ```

6. **Watch it rejoin:**
   ```bash
   watch -n 2 './scripts/nodetool.sh status'
   ```
   Node should transition from **UJ** (Up Joining) to **UN** (Up Normal).

### 🔴 Advanced: Node Failure and Recovery (Hinted Handoff)

This exercise demonstrates what happens when a node goes down, receives updates while down, and then rejoins the cluster. You'll see how DSE handles missed writes through hinted handoff.

**Prerequisites:**
- Cluster is running and healthy
- Training keyspace exists (run `./scripts/cqlsh.sh -f training/labs/sample-keyspace.cql` if needed)

**Step 1: Baseline - Check current data**

```bash
# Check all nodes are healthy
./scripts/nodetool.sh status

# View current data
./scripts/cqlsh.sh -e "SELECT * FROM training.sample;"

# Note the current row count and data
```

**Step 2: Stop a node (simulate failure)**

```bash
# Stop dse-node-2
docker-compose stop dse-node-2

# Verify it's down
./scripts/nodetool.sh status
# dse-node-2 should show as DN (Down Normal)

# Check hints directory on seed (where hints will be stored)
./scripts/shell.sh
# Inside container:
ls -la /var/lib/cassandra/hints/
exit
```

**Step 3: Make updates while node is down**

```bash
# Insert new data while node-2 is down
./scripts/cqlsh.sh <<'CQL'
USE training;
INSERT INTO sample (id, name, value, created_at) 
VALUES (uuid(), 'written_while_down', 999, toTimestamp(now()));
INSERT INTO sample (id, name, value, created_at) 
VALUES (uuid(), 'another_write', 888, toTimestamp(now()));
SELECT * FROM sample;
CQL

# Verify data exists on available nodes
./scripts/cqlsh.sh -e "SELECT * FROM training.sample WHERE name = 'written_while_down' ALLOW FILTERING;"
```

**Step 4: Check hints (missed writes)**

```bash
# Check hints directory on seed node (this is the primary way to verify hints)
./scripts/shell.sh dse-seed
# Inside container:
ls -lh /var/lib/cassandra/hints/
# You should see hint files for dse-node-2
# Hint files are typically named with timestamps or node identifiers
exit

💡 **Note**: Hint files are created when writes occur to a down node. The files may not appear immediately, and log messages about hints may be sparse. The presence of hint files in `/var/lib/cassandra/hints/` is the primary indicator that hints are being stored.

**Step 5: Restart the node**

```bash
# Restart dse-node-2
docker-compose start dse-node-2

# Monitor it rejoining
./scripts/nodetool.sh status
# Should see: DN → UJ (Up Joining) → UN (Up Normal)
```

**Step 6: Observe hinted handoff**

```bash
# Once node is UN, hints will be delivered automatically
# First, check hints directory to see hint files before delivery
./scripts/shell.sh dse-seed
# Inside container:
ls -lh /var/lib/cassandra/hints/
exit

# Monitor logs for hint delivery activity
# Check logs before and after hint delivery
echo "Checking logs for hint delivery messages:"
./scripts/logs.sh dse-seed --tail 200 | grep -iE "hint|handoff|deliver|replay|mutation.*hint"
# You should see messages about finished hinted handoffs and deleted hints. Because of the shared-nothing architecture, they may be on dse-node-1 as well.

# Also check system.log directly on the node receiving hints
./scripts/shell.sh dse-node-2
# Inside container:
echo "Checking system.log for hint delivery:"
tail -200 /var/log/cassandra/system.log | grep -iE "hint|handoff|deliver|replay|mutation"
exit
```

Look at the MutationStage line in your output. This is where the magic is happening on the receiving node (dse-node-2).

**What these numbers mean:**
- In the first snippet, you have: MutationStage | 0 | 0 | x
- In the second snippet (a few seconds later): MutationStage | 0 | 0 | y

The third column is the Completed Tasks count and it's incrementing. This proves that dse-node-2 is actively processing writes. When dse-seed sends a hint, it arrives at dse-node-2 as a standard mutation and is handled by the MutationStage thread pool.

**Why you don't see "Hint" in these logs**
The Receiver is "Blind": dse-node-2 doesn't actually know these are "hints." To this node, they are just incoming data packets from another node saying "Please write this to disk."

The Sender is "Aware": Only the node that stored the hint (dse-seed) logs the word "Hint" because it has to manage the hint files, the replay logic, and the deletion of the files after the handoff.

```bash
# Wait for hints to be delivered (hints are delivered asynchronously)

# Check hints directory again (hint files should be processed/removed after delivery)
./scripts/shell.sh dse-seed
# Inside container:
ls -lh /var/lib/cassandra/hints/
# Hint files should be gone or significantly reduced after delivery
exit
```

**The best way to verify hints were delivered:**
1. Hint files are gone/reduced (above)
2. Check logs for delivery activity (above)
3. Data appears on the recovered node (Step 7)

**Step 7: Verify data consistency**

```bash
# Check data on the recovered node
./scripts/shell.sh dse-node-2
cqlsh <<'CQL'
CONSISTENCY ONE;
USE training;
SELECT * FROM sample WHERE name = 'written_while_down' ALLOW FILTERING;
SELECT * FROM sample WHERE name = 'another_write' ALLOW FILTERING;
CQL

# Check from different consistency levels
cqlsh <<'CQL'
CONSISTENCY QUORUM;
USE training;
SELECT * FROM sample;
CQL

exit
```

**Step 8: Run repair to ensure consistency**

```bash
# Even though hints were delivered, run repair to ensure consistency
./scripts/nodetool.sh repair training -pr

# Monitor repair progress
./scripts/nodetool.sh netstats
```

**Step 9: Verify final state**

```bash
# Check all nodes have the same data
./scripts/nodetool.sh status
# All should be UN

# Verify data consistency
./scripts/cqlsh.sh -e "SELECT COUNT(*) FROM training.sample;"
# Should be consistent across nodes
```

**Key Learning Points:**

- ✅ **Hinted Handoff**: When a node is down, writes are stored as hints on coordinator nodes
- ✅ **Automatic Recovery**: When node rejoins, hints are automatically delivered
- ✅ **Eventual Consistency**: Data becomes consistent after hints are delivered
- ✅ **Repair**: Still recommended after node recovery to ensure full consistency
- ✅ **Monitoring**: Check hints directory (`/var/lib/cassandra/hints/`) to verify hints exist and are delivered
- ✅ **Logs**: Hint-related log messages may be sparse; checking the hints directory is more reliable

**Troubleshooting:**

- If hints aren't delivered: Check `max_hint_window_in_ms` in cassandra.yaml (default: 3 hours)
- If data is missing: Check logs for hint delivery errors
- If node won't rejoin: Check SEEDS configuration and network connectivity

### 🔴 Advanced: Complete Decommission Workflow

**⚠️ Warning**: This permanently removes a node. Only do this if you're ready to rebuild.

1. **Pre-decommission checks:**
   ```bash
   # Verify cluster health
   ./scripts/nodetool.sh status
   
   # Check replication factor
   ./scripts/cqlsh.sh -e "DESCRIBE KEYSPACE training;"
   ```

2. **Take snapshots:**
   ```bash
   ./scripts/nodetool.sh snapshot -t before_decommission
   ./scripts/nodetool-node.sh dse-node-1 snapshot -t before_decommission
   ./scripts/nodetool-node.sh dse-node-2 snapshot -t before_decommission
   ```

3. **Monitor during decommission:**
   ```bash
   # Terminal 1: Start decommission
   ./scripts/nodetool-node.sh dse-node-2 decommission
   
   # Terminal 2: Monitor streaming
   watch -n 2 './scripts/nodetool-node.sh dse-node-2 netstats'
   
   # Terminal 3: Monitor ring
   watch -n 2 './scripts/nodetool.sh status'
   ```

4. **Verify completion:**
   ```bash
   # Node should be gone from ring
   ./scripts/nodetool.sh status
   
   # Check data was streamed
   ./scripts/nodetool.sh info
   ```

5. **Run cleanup on remaining nodes:**
   ```bash
   ./scripts/nodetool.sh cleanup
   ./scripts/nodetool-node.sh dse-node-1 cleanup
   ```

6. **Stop and remove container:**
   ```bash
   docker-compose stop dse-node-2
   docker-compose rm dse-node-2
   ```

## 🐛 Troubleshooting Advanced Operations

### Decommission Hangs or Fails

**Symptoms:**
- Decommission doesn't complete
- Streaming stalls
- Node remains in ring

**Solutions:**

1. **Check logs:**
   ```bash
   ./scripts/logs.sh dse-node-1 --tail 100
   ```

2. **Check network connectivity:**
   ```bash
   ./scripts/nodetool.sh netstats
   ```

3. **Check disk space** on destination nodes:
   ```bash
   ./scripts/shell.sh
   df -h /var/lib/cassandra
   ```

4. **Force decommission** (last resort):
   ```bash
   # Stop the node
   docker-compose stop dse-node-1
   
   # Remove from ring using removenode
   ./scripts/nodetool.sh removenode <host-id>
   ```

### Removenode Fails

**Symptoms:**
- Removenode command fails
- Node remains in ring
- Error messages about node state

**Solutions:**

1. **Verify node is actually down:**
   ```bash
   ./scripts/nodetool.sh status
   ./scripts/nodetool.sh gossipinfo
   ```

2. **Use force flag** (if node is definitely down):
   ```bash
   ./scripts/nodetool.sh removenode <host-id> --force
   ```

3. **Check for other operations** blocking removenode:
   ```bash
   ./scripts/nodetool.sh netstats
   ./scripts/nodetool.sh compactionstats
   ```

### Data Not Rebalancing After Removal

**Symptoms:**
- Load uneven after node removal
- Some nodes have more data than others

**Solutions:**

1. **Run cleanup** on all nodes:
   ```bash
   ./scripts/nodetool.sh cleanup
   ./scripts/nodetool-node.sh dse-node-1 cleanup
   ```

2. **Check replication factor:**
   ```bash
   ./scripts/cqlsh.sh -e "DESCRIBE KEYSPACE training;"
   ```
   Ensure RF is appropriate for remaining nodes.

3. **Wait for natural rebalancing** (can take time):
   ```bash
   ./scripts/nodetool.sh info  # Check load over time
   ```

## 📚 Best Practices

1. **Always backup first**: Take snapshots before topology changes
2. **Plan ahead**: Understand impact before starting operations
3. **Monitor closely**: Watch logs, metrics, and ring state
4. **Test in non-production**: Practice these operations first
5. **Document everything**: Keep notes of what you did and why
6. **Have rollback plan**: Know how to recover if things go wrong
7. **Verify RF**: Ensure replication factor is sufficient
8. **Clean up after**: Run cleanup on remaining nodes after removals

## 🚀 Next

Go to [11 – Production Readiness](11-production-readiness.md) for production deployment best practices and checklists.

## 📖 References

- [DSE 6.8 Node Operations](https://docs.datastax.com/en/dse/6.8/managing/operations/)
- [DSE 6.9 Node Operations](https://docs.datastax.com/en/dse/6.9/managing/operations/)
- [DSE 6.8 Decommissioning Nodes](https://docs.datastax.com/en/dse/6.8/managing/operations/opsDecommissionNode.html)
- [DSE 6.9 Decommissioning Nodes](https://docs.datastax.com/en/dse/6.9/managing/operations/opsDecommissionNode.html)
- [DSE 6.8 Removing Nodes](https://docs.datastax.com/en/dse/6.8/managing/operations/opsRemoveNode.html)
- [DSE 6.9 Removing Nodes](https://docs.datastax.com/en/dse/6.9/managing/operations/opsRemoveNode.html)
- [DSE 6.8 Token Management](https://docs.datastax.com/en/dse/6.8/managing/operations/opsTokens.html)
- [DSE 6.9 Token Management](https://docs.datastax.com/en/dse/6.9/managing/operations/opsTokens.html)
- [DSE 6.8 Hinted Handoff](https://docs.datastax.com/en/dse/6.8/managing/operations/opsHintedHandoff.html)
- [DSE 6.9 Hinted Handoff](https://docs.datastax.com/en/dse/6.9/managing/operations/opsHintedHandoff.html)

💡 **Performance Note**: Decommissioning and node addition operations benefit from zero-copy streaming (available in both DSE 6.8 and 6.9), providing up to 4x faster performance compared to earlier versions.
