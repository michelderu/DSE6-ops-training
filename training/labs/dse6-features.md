# DSE 6.8/6.9 Features Lab Exercises

Hands-on exercises to explore DSE 6.8 and 6.9 specific features and improvements.

## 🎯 Lab Objectives

- Explore DSE 6.8 and 6.9 performance improvements
- Understand zero-copy streaming benefits (DSE 6.9)
- Practice with DSE 6 specific utilities and commands
- Compare DSE 6.8 vs 6.9 behavior where applicable

## 📋 Prerequisites

- Cluster is running and healthy (`./scripts/nodetool.sh status` shows all nodes UN)
- Training keyspace exists (run `./scripts/cqlsh.sh -f training/labs/sample-keyspace.cql` if needed)
- Basic understanding of repair, backup, and node operations

## 🟢 Beginner: Verify DSE Version

### Exercise 1: Check DSE Version

1. **Check DSE version** on each node:
   ```bash
   ./scripts/nodetool.sh version
   ./scripts/nodetool-node.sh dse-node-1 version
   ./scripts/nodetool-node.sh dse-node-2 version
   ```

2. **Check cluster description** for version information:
   ```bash
   ./scripts/nodetool.sh describecluster
   ```

3. **Verify DSE 6 features**:
   ```bash
   ./scripts/dsetool.sh status
   ```

**Expected output**: Should show DSE 6.8.x or 6.9.x version information.

## 🟡 Intermediate: Zero-Copy Streaming Performance (DSE 6.9)

**Note**: This exercise demonstrates the performance improvements in DSE 6.9. If you're using DSE 6.8, you can still complete the exercise but won't see the same performance benefits.

### Exercise 2: Measure Streaming Performance During Repair

1. **Baseline measurement** - Check current data size:
   ```bash
   ./scripts/nodetool.sh info | grep Load
   ```

2. **Insert test data** (if needed):
   ```bash
   ./scripts/cqlsh.sh <<'CQL'
   USE training;
   -- Insert multiple rows to create some data
   BEGIN BATCH
   INSERT INTO sample (id, name, value, created_at) VALUES (uuid(), 'test1', 100, toTimestamp(now()));
   INSERT INTO sample (id, name, value, created_at) VALUES (uuid(), 'test2', 200, toTimestamp(now()));
   INSERT INTO sample (id, name, value, created_at) VALUES (uuid(), 'test3', 300, toTimestamp(now()));
   APPLY BATCH;
   CQL
   ```

3. **Start repair and measure time**:
   ```bash
   # Record start time
   START_TIME=$(date +%s)
   
   # Start repair
   ./scripts/nodetool.sh repair training -pr
   
   # Monitor streaming progress
   watch -n 1 './scripts/nodetool.sh netstats'
   
   # After repair completes, record end time
   END_TIME=$(date +%s)
   DURATION=$((END_TIME - START_TIME))
   echo "Repair duration: ${DURATION} seconds"
   ```

4. **Compare with DSE 6.8** (if you have access to both):
   - DSE 6.9 should complete repair significantly faster (up to 4x) due to zero-copy streaming
   - Note the difference in streaming throughput shown in `netstats`

**Key Learning**: DSE 6.9's zero-copy streaming makes repair, node addition, and recovery operations much faster.

## 🟡 Intermediate: Node Addition Performance (DSE 6.9)

### Exercise 3: Add a Node and Measure Bootstrap Time

**Note**: This requires modifying docker-compose.yml to add a fourth node, or simulating by stopping and restarting a node.

1. **Stop a node** (simulate node addition scenario):
   ```bash
   docker-compose stop dse-node-2
   ```

2. **Clear node data** (simulate fresh node):
   ```bash
   # Note: In production, you'd have a new node. For lab, we'll restart existing node.
   # Skip clearing data for this exercise - just restart
   ```

3. **Restart and measure bootstrap time**:
   ```bash
   START_TIME=$(date +%s)
   
   docker-compose start dse-node-2
   
   # Monitor bootstrap progress
   watch -n 2 './scripts/nodetool.sh status'
   
   # Wait until node shows UN
   while ! ./scripts/nodetool.sh status | grep -q "dse-node-2.*UN"; do
     sleep 2
   done
   
   END_TIME=$(date +%s)
   DURATION=$((END_TIME - START_TIME))
   echo "Bootstrap duration: ${DURATION} seconds"
   ```

4. **Monitor streaming**:
   ```bash
   ./scripts/nodetool-node.sh dse-node-2 netstats
   ```

**Key Learning**: DSE 6.9's zero-copy streaming makes node bootstrap and data streaming much faster.

## 🔴 Advanced: Performance Comparison Lab

### Exercise 4: Compare Repair Performance Metrics

1. **Before repair** - Collect baseline metrics:
   ```bash
   # Record metrics
   ./scripts/nodetool.sh info > /tmp/before_repair.info
   ./scripts/nodetool.sh tablestats training > /tmp/before_repair.tablestats
   ```

2. **Run repair** with monitoring:
   ```bash
   # Terminal 1: Run repair
   ./scripts/nodetool.sh repair training -pr
   
   # Terminal 2: Monitor network stats
   watch -n 1 './scripts/nodetool.sh netstats'
   
   # Terminal 3: Monitor compaction stats
   watch -n 1 './scripts/nodetool.sh compactionstats'
   ```

3. **After repair** - Collect post-repair metrics:
   ```bash
   ./scripts/nodetool.sh info > /tmp/after_repair.info
   ./scripts/nodetool.sh tablestats training > /tmp/after_repair.tablestats
   ```

4. **Compare metrics**:
   ```bash
   diff /tmp/before_repair.info /tmp/after_repair.info
   diff /tmp/before_repair.tablestats /tmp/after_repair.tablestats
   ```

**Key Learning**: Understand how repair operations affect cluster metrics and performance.

## 🔴 Advanced: DSE 6.8 vs 6.9 Feature Comparison

### Exercise 5: Document Version-Specific Features

1. **Check available features**:
   ```bash
   ./scripts/dsetool.sh status
   ./scripts/nodetool.sh describecluster
   ```

2. **Review DSE 6.9 release notes** for new features:
   - Zero-copy streaming
   - Improved repair performance
   - Enhanced monitoring capabilities

3. **Document differences**:
   - Create a comparison table of DSE 6.8 vs 6.9 features
   - Note which features are available in your version
   - Identify upgrade considerations

**Key Learning**: Understand what features are available in DSE 6.8 vs 6.9 and plan upgrades accordingly.

## 📚 DSE 6.8 vs 6.9 Key Differences

### Performance Improvements (DSE 6.9)

- **Zero-copy streaming**: Up to 4x faster streaming, repair, and node operations
- **Improved recovery**: Faster recovery from node failures
- **Enhanced node addition**: Faster bootstrap and data streaming

### Compatibility

- DSE 6.9 is backward compatible with DSE 6.8
- Upgrade path: DSE 6.8 → DSE 6.9 (one node at a time)
- During partial upgrade, certain operations are restricted (see upgrade docs)

### When to Use DSE 6.8 vs 6.9

- **DSE 6.8**: Stable, production-proven version
- **DSE 6.9**: Latest version with performance improvements, recommended for new deployments

## 🎓 Learning Objectives

After completing these exercises, you should be able to:

- ✅ Verify DSE version and features
- ✅ Understand zero-copy streaming benefits (DSE 6.9)
- ✅ Measure and compare performance improvements
- ✅ Use DSE 6 specific utilities effectively
- ✅ Plan upgrades from DSE 6.8 to 6.9

## 📖 References

- [DSE 6.8 Release Notes](https://docs.datastax.com/en/dse/6.8/release-notes/release-notes/dse-68-release-notes.html)
- [DSE 6.9 Release Notes](https://docs.datastax.com/en/dse/6.9/release-notes/release-notes/dse-69-release-notes.html)
- [Upgrading DSE 6.8 to 6.9](https://docs.datastax.com/en/upgrading/datastax-enterprise/dse-68-to-69.html)
- [DSE 6.8 Performance Tuning](https://docs.datastax.com/en/dse/6.8/managing/performance/)
- [DSE 6.9 Performance Tuning](https://docs.datastax.com/en/dse/6.9/managing/performance/)

---

💡 **Tip**: These exercises help you understand DSE 6.8 and 6.9 capabilities. Practice regularly to build operational expertise!
