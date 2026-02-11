# DSE 6.8/6.9 Features Lab Exercises

Hands-on exercises to explore DSE 6.8 and 6.9 specific features and improvements.

## 🎯 Lab Objectives

- Explore DSE 6.8 and 6.9 performance improvements
- Understand zero-copy streaming benefits (available in DSE 6.8 and 6.9)
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

## 🟡 Intermediate: Zero-Copy Streaming Performance

**Note**: Zero-copy streaming is available in both DSE 6.8 and 6.9, providing up to 4x faster streaming, repair, and node operations compared to earlier versions.

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

4. **Observe streaming performance**:
   - Both DSE 6.8 and 6.9 use zero-copy streaming, completing repair significantly faster (up to 4x) compared to earlier versions
   - Note the streaming throughput shown in `netstats`

**Key Learning**: Zero-copy streaming (available in both DSE 6.8 and 6.9) makes repair, node addition, and recovery operations much faster compared to earlier versions.

## 🟡 Intermediate: Node Addition Performance

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

**Key Learning**: Zero-copy streaming (available in both DSE 6.8 and 6.9) makes node bootstrap and data streaming much faster compared to earlier versions.

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

2. **Review DSE 6.8 and 6.9 release notes** for features:
   - Zero-copy streaming (available in both versions)
   - Vector search (DSE 6.9 only)
   - SAI enhancements (text analyzers, OR operator in DSE 6.9)
   - Improved repair performance

3. **Compare with the feature table**:
   - Review the [DSE 6.8 vs 6.9 Functional Comparison](#dse-68-vs-69-functional-comparison) table below
   - Note which features are available in your version
   - Identify upgrade considerations if planning to move from 6.8 to 6.9

**Key Learning**: Understand what features are available in DSE 6.8 vs 6.9 and plan upgrades accordingly. DSE 6.9 adds vector search capabilities and enhanced SAI features for AI/ML workloads.

## 📚 DSE 6.8 vs 6.9 Functional Comparison

### Feature Comparison Table

| Feature | DSE 6.8 | DSE 6.9 | Notes |
|---------|---------|---------|-------|
| **Core Database** |
| Zero-copy streaming | ✅ | ✅ | Up to 4x faster streaming, repair, and node operations |
| NodeSync | ✅ | ✅ | Continuous background repair |
| Storage-Attached Indexing (SAI) | ✅ | ✅ | Secondary indexing with improved performance |
| SAI text analyzers | ❌ | ✅ | Enable semantic filtering and term matching on strings |
| SAI OR operator | ❌ | ✅ | OR logic support in SAI queries (in addition to AND) |
| SAI vector indexing | ❌ | ✅ | Index and query VECTOR data type |
| **Vector Search** |
| Vector search (JVector) | ❌ | ✅ | 10x faster than Lucene-based search; requires Vector Add-on |
| Vector embeddings (VECTOR type) | ❌ | ✅ | Fixed-dimensionality vector storage |
| Vector similarity search | ❌ | ✅ | RAG and AI agent use cases |
| **Search & Indexing** |
| DSE Search (Solr) | ✅ | ✅ | Full-text search capabilities |
| Secondary indexes (2i) | ✅ | ✅ | Traditional secondary indexing |
| **Analytics** |
| DSE Analytics (Spark) | ✅ | ✅ | Batch and streaming analytics |
| AlwaysOn SQL | ✅ | ✅ | SQL interface for Spark |
| **Graph** |
| DSE Graph | ✅ | ✅ | Graph database with Gremlin |
| **Security** |
| DSE Advanced Security | ✅ | ✅ | RBAC, LDAP, Kerberos, encryption |
| **Operations** |
| Backup & Restore Service | ✅ | ✅ | CQL-based automated backup |
| Snapshot & incremental backup | ✅ | ✅ | Traditional backup methods |
| **Performance** |
| Zero-copy streaming performance | ✅ | ✅ | Both versions benefit from zero-copy streaming |
| SAI write performance | ✅ | ✅ | 43x better than secondary indexes |
| SAI latency improvements | ✅ | ✅ | 230x better latency than secondary indexes |

### Key Functional Differences

**DSE 6.9 New Features:**
- **Vector Search**: Powered by JVector engine, 10x faster than Lucene-based search. Enables AI/ML workloads with vector embeddings and similarity search.
- **SAI Text Analyzers**: Enhanced SAI functionality with text analyzers for semantic filtering, term matching, tokenization, and keyword filtering.
- **SAI OR Operator**: Expanded query capabilities with OR logic support in SAI queries.
- **Vector Indexing**: Native support for VECTOR data type indexing and querying.

**Shared Features (Both Versions):**
- Zero-copy streaming for improved performance
- NodeSync continuous background repair
- Core SAI functionality (without text analyzers and OR operator in 6.8)
- All DSE workloads (Search, Analytics, Graph)
- Security and operations features

### Compatibility

- DSE 6.9 is backward compatible with DSE 6.8
- Upgrade path: DSE 6.8 → DSE 6.9 (one node at a time)
- During partial upgrade, certain operations are restricted (see upgrade docs)
- Vector search requires Vector Add-on in DSE 6.9

### When to Use DSE 6.8 vs 6.9

- **DSE 6.8**: Stable, production-proven version with all core DSE 6 features. Suitable for traditional database workloads.
- **DSE 6.9**: Latest version with vector search capabilities and enhanced SAI features. Recommended for:
  - AI/ML workloads requiring vector similarity search
  - Applications needing advanced text analysis and semantic filtering
  - New deployments requiring latest features and improvements

## 🎓 Learning Objectives

After completing these exercises, you should be able to:

- ✅ Verify DSE version and features
- ✅ Understand zero-copy streaming benefits (available in DSE 6.8 and 6.9)
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
