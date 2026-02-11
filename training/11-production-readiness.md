# Module 11 — Production Readiness

Prepare your DSE cluster for production deployment. This module covers essential production practices, checklists, and considerations beyond the training environment.

## 🎯 Goals

- ✅ Understand production vs. training differences
- 📋 Use production readiness checklists
- 🔒 Apply security best practices
- 📊 Set up monitoring and alerting
- 🛡️ Plan for disaster recovery
- 📈 Understand capacity planning basics

## ⚠️ Training vs. Production

**This training environment is NOT production-ready:**

| Aspect | Training | Production |
|--------|----------|------------|
| **Nodes per host** | Multiple (3 nodes on 1 host) | One node per physical host |
| **Resource limits** | Minimal (1GB heap) | Properly sized (8GB+ heap) |
| **Data persistence** | Container volumes | Persistent storage (EBS, etc.) |
| **Security** | Basic | Full encryption, authentication |
| **Monitoring** | Manual checks | Automated monitoring/alerting |
| **Backup** | Manual snapshots | Automated backup/restore |
| **High availability** | Single host | Multi-DC, multi-region |

💡 **Key principle**: In production, **one DSE node per physical host** to avoid single points of failure.

## 📋 Production Readiness Checklist

### Infrastructure

- [ ] **One node per host**: Each DSE node runs on a dedicated physical or virtual machine
- [ ] **Network**: Low-latency, high-bandwidth network between nodes
- [ ] **Storage**: Fast, persistent storage (SSD recommended)
- [ ] **Resources**: Adequate CPU, RAM, disk (see capacity planning)
- [ ] **Firewall**: Properly configured (ports 7000, 9042, 7199)
- [ ] **DNS**: Proper hostname resolution
- [ ] **NTP**: Time synchronization across all nodes

### Configuration

- [ ] **Cluster name**: Unique, descriptive cluster name
- [ ] **Seeds**: 2-3 seed nodes per datacenter
- [ ] **Snitch**: Appropriate snitch (GossipingPropertyFileSnitch recommended)
- [ ] **Replication**: NetworkTopologyStrategy with appropriate RF
- [ ] **Consistency**: Appropriate consistency levels for workload
- [ ] **Heap size**: Set to 50% of available RAM (max 32GB)
- [ ] **GC tuning**: G1GC with appropriate settings
- [ ] **Compaction**: Appropriate strategy per table

### Security

- [ ] **Authentication**: DSE authentication enabled
- [ ] **Authorization**: Role-based access control configured
- [ ] **Internode encryption**: SSL/TLS enabled (`internode_encryption: all`)
- [ ] **Client encryption**: SSL/TLS enabled for client connections
- [ ] **Config encryption**: Sensitive passwords encrypted
- [ ] **Firewall rules**: Only necessary ports open
- [ ] **Key management**: System keys properly secured
- [ ] **Audit logging**: Enabled for compliance (if required)

### Monitoring & Alerting

- [ ] **JMX access**: Secured JMX access for monitoring
- [ ] **Metrics collection**: Prometheus, Grafana, or similar
- [ ] **Log aggregation**: Centralized logging (ELK, Splunk, etc.)
- [ ] **Alerting**: Alerts for critical metrics
- [ ] **Dashboards**: Key metrics visualized
- [ ] **Health checks**: Automated health check scripts

### Backup & Recovery

- [ ] **Backup strategy**: Automated snapshot schedule
- [ ] **Incremental backup**: Enabled and automated
- [ ] **Backup storage**: Off-cluster storage (S3, NFS, etc.)
- [ ] **Backup retention**: Defined retention policy
- [ ] **Restore testing**: Regular restore tests
- [ ] **Disaster recovery**: DR plan documented and tested

### Operations

- [ ] **Runbooks**: Documented procedures for common tasks
- [ ] **On-call rotation**: 24/7 coverage plan
- [ ] **Change management**: Process for configuration changes
- [ ] **Capacity planning**: Growth projections and scaling plan
- [ ] **Maintenance windows**: Scheduled maintenance procedures
- [ ] **Repair strategy**: NodeSync enabled for appropriate tables, or scheduled `nodetool repair` (see [07 – Repair & Maintenance](07-repair-maintenance.md))
- [ ] **Documentation**: Architecture and operational docs

## 🔒 Security Best Practices

### Authentication & Authorization

**Enable DSE authentication:**

```yaml
# In cassandra.yaml
authenticator: com.datastax.bdp.cassandra.auth.DseAuthenticator
authorizer: com.datastax.bdp.cassandra.auth.DseAuthorizer
role_manager: com.datastax.bdp.cassandra.auth.DseRoleManager
```

**Create roles:**

```cql
-- Create admin role
CREATE ROLE admin WITH PASSWORD = 'secure_password' AND SUPERUSER = true AND LOGIN = true;

-- Create application role
CREATE ROLE app_user WITH PASSWORD = 'app_password' AND LOGIN = true;

-- Grant permissions
GRANT ALL ON KEYSPACE my_keyspace TO app_user;
```

### Encryption

**Internode encryption** (see Module 09):

```yaml
# In cassandra.yaml
server_encryption_options:
    internode_encryption: all
    keystore: /etc/dse/conf/.keystore
    keystore_password: <encrypted>
    truststore: /etc/dse/conf/.truststore
    truststore_password: <encrypted>
    require_client_auth: true
```

**Client encryption:**

```yaml
client_encryption_options:
    enabled: true
    keystore: /etc/dse/conf/.client-keystore
    keystore_password: <encrypted>
```

**Configuration encryption** (see Module 09):

```yaml
# In dse.yaml
config_encryption_active: true
config_encryption_key_name: system_key
```

### Network Security

- **Firewall**: Only open necessary ports (7000, 9042, 7199)
- **VPN**: Use VPN for administrative access
- **VPC**: Isolate DSE nodes in private subnets
- **Security groups**: Restrict access by IP/security group

## 📊 Monitoring & Alerting

### Key Metrics to Monitor

**Cluster Health:**
- Node status (UN/DN/UJ)
- Ring state
- Gossip convergence
- Schema version consistency

**Performance:**
- Read/write latency (p50, p95, p99)
- Throughput (ops/sec)
- Heap usage
- GC pause times
- Compaction backlog

**Capacity:**
- Disk usage
- Data size per node
- SSTable count
- Pending compactions

**Errors:**
- Timeout rates
- Unavailable exceptions
- Failed mutations
- GC failures

### Alert Thresholds

**Critical (immediate action):**
- Node down (DN)
- Disk > 90% full
- Heap > 90%
- GC pause > 5 seconds
- Read latency p99 > 1000ms

**Warning (investigate soon):**
- Disk > 75% full
- Heap > 75%
- Read latency p95 > 500ms
- Compaction backlog > 100
- Replication factor violation

### Monitoring Tools

**Recommended stack:**
- **Metrics**: Prometheus + node_exporter
- **Visualization**: Grafana
- **Logs**: ELK stack (Elasticsearch, Logstash, Kibana)
- **Alerting**: Alertmanager or PagerDuty

**JMX Exporter:**

```yaml
# jmx_exporter config
rules:
  - pattern: ".*"
```

## 💾 Backup & Disaster Recovery

### Backup Strategy

**Full snapshots:**
- Frequency: Daily or weekly
- Retention: 30-90 days
- Storage: Off-cluster (S3, NFS)

**Incremental backups:**
- Frequency: Continuous (after each flush)
- Retention: 7-30 days
- Storage: Off-cluster

**Backup automation:**

```bash
#!/bin/bash
# Example backup script
DATE=$(date +%Y%m%d)
nodetool snapshot -t daily_${DATE}
# Copy snapshots to S3/NFS
aws s3 sync /var/lib/cassandra/data s3://backup-bucket/daily_${DATE}/
```

### Repair Strategy (DSE 6.8/6.9)

**Choose between NodeSync and traditional repair:**

**NodeSync (recommended for most workloads):**
- ✅ Continuous background repair, no manual scheduling
- ✅ Automatic consistency maintenance
- ✅ Best for read-heavy or balanced workloads (writes < 20% of operations)
- ⚠️ May have higher CPU overhead for write-heavy workloads

**Enable NodeSync on production tables:**

```cql
ALTER TABLE my_keyspace.my_table WITH nodesync = true;
```

**Monitor NodeSync:**

```bash
nodetool nodesyncservice status
nodetool nodesyncservice getrate
```

**Traditional `nodetool repair` (for write-heavy workloads):**
- ✅ Lower CPU overhead for write-heavy workloads (>20% writes)
- ✅ Explicit control over repair timing
- ⚠️ Requires scheduling and monitoring

**Repair schedule example:**

```bash
# Run primary-only repair weekly
nodetool repair -pr -full
```

💡 **Best practice**: Prefer NodeSync for most tables. Use `nodetool repair` only for write-heavy workloads where NodeSync CPU overhead is too high, or when NodeSync is disabled. See [07 – Repair & Maintenance](07-repair-maintenance.md) for details.

### Disaster Recovery Plan

**RTO (Recovery Time Objective)**: Target time to restore service
**RPO (Recovery Point Objective)**: Maximum acceptable data loss

**DR Scenarios:**

1. **Single node failure**: 
   - Replace node, bootstrap from existing cluster
   - RTO: Minutes to hours

2. **Datacenter failure**:
   - Failover to secondary DC
   - RTO: Minutes (if multi-DC)

3. **Complete cluster loss**:
   - Restore from backups
   - RTO: Hours to days

**DR Testing:**
- Test restore procedures quarterly
- Document restore times
- Verify backup integrity regularly

## 📈 Capacity Planning

### Resource Sizing

**CPU:**
- Minimum: 8 cores per node
- Recommended: 16+ cores
- More cores = better compaction performance

**Memory:**
- Heap: 50% of RAM (max 32GB)
- OS cache: Remaining RAM for page cache
- Example: 64GB RAM → 32GB heap, 32GB OS cache

**Disk:**
- SSD recommended for production
- Plan for 3-5x data size (replication + overhead)
- Monitor disk I/O (iostat)

**Network:**
- 10Gbps recommended for production
- Monitor network utilization

### Growth Planning

**Data growth:**
- Track data size over time
- Project growth rate
- Plan for 6-12 months ahead

**Traffic growth:**
- Monitor ops/sec trends
- Plan for peak capacity
- Consider read/write ratio changes

**Scaling:**
- **Vertical**: Increase node resources (CPU, RAM, disk)
- **Horizontal**: Add more nodes
- **Both**: Often best approach

## 🏗️ Multi-Datacenter Setup

### Architecture

**Requirements:**
- Low latency between DCs (< 10ms recommended)
- High bandwidth
- Proper replication strategy

**Configuration:**

```cql
-- Create keyspace with multi-DC replication
CREATE KEYSPACE my_keyspace
WITH replication = {
  'class': 'NetworkTopologyStrategy',
  'DC1': 3,
  'DC2': 3
};
```

**Consistency levels:**
- Use `LOCAL_QUORUM` for DC-local operations
- Use `EACH_QUORUM` for cross-DC consistency

### Snitch Configuration

**GossipingPropertyFileSnitch** (recommended):

```yaml
# In cassandra.yaml
endpoint_snitch: GossipingPropertyFileSnitch
```

**cassandra-rackdc.properties** on each node:

```properties
dc=DC1
rack=RACK1
```

## 🧪 Production Readiness Exercises

### 🟢 Beginner: Review Checklist

1. **Review the production checklist** above
2. **Identify gaps** in your current setup
3. **Document** what would need to change for production
4. **Research** production deployment guides

### 🟡 Intermediate: Security Hardening

1. **Enable authentication** (if not already):
   ```cql
   -- Create admin user
   CREATE ROLE admin WITH PASSWORD = 'secure_pass' AND SUPERUSER = true AND LOGIN = true;
   ```

2. **Test authentication**:
   ```bash
   ./scripts/cqlsh.sh -u admin -p secure_pass
   ```

3. **Review encryption settings** (Module 09)
4. **Document** security configuration

### 🔴 Advanced: Monitoring Setup

1. **Set up basic monitoring**:
   - Install Prometheus node_exporter (if possible)
   - Create basic Grafana dashboard
   - Set up log aggregation

2. **Create alerting rules**:
   - Node down alert
   - High heap usage alert
   - High latency alert

3. **Test alerting**:
   - Simulate node failure
   - Verify alerts trigger
   - Test alert resolution

## 📚 Production Resources

### Documentation

- [DSE 6.8 Production Guide](https://docs.datastax.com/en/dse/6.8/managing/)
- [DSE 6.9 Production Guide](https://docs.datastax.com/en/dse/6.9/managing/)
- [DSE 6.8 Security Guide](https://docs.datastax.com/en/dse/6.8/managing/security/)
- [DSE 6.9 Security Guide](https://docs.datastax.com/en/dse/6.9/managing/security/)
- [DSE 6.8 Performance Tuning](https://docs.datastax.com/en/dse/6.8/managing/performance/)
- [DSE 6.9 Performance Tuning](https://docs.datastax.com/en/dse/6.9/managing/performance/)

### Tools

- **DataStax OpsCenter**: Management and monitoring (if available)
- **NodeSync** (DSE 6.8/6.9): Continuous background repair (preferred for most workloads; see [07 – Repair & Maintenance](07-repair-maintenance.md))
- **Reaper**: Automated repair scheduling (alternative to NodeSync for write-heavy workloads)
- **Medusa**: Backup and restore tool
- **Cassandra Reaper**: Repair management

### Community

- DataStax Community Forum
- Cassandra Users mailing list
- DSE Slack channels

## 🎓 Key Takeaways

1. **One node per host**: Critical for production
2. **Security first**: Enable authentication, encryption, authorization
3. **Monitor everything**: Metrics, logs, alerts
4. **Backup regularly**: Automated backups with tested restore
5. **Plan for growth**: Capacity planning and scaling strategy
6. **Document everything**: Runbooks, procedures, architecture
7. **Test DR**: Regular disaster recovery testing

## 🚀 Next Steps

After completing this training:

1. **Review** all modules and ensure understanding
2. **Practice** in a non-production environment
3. **Read** production deployment guides
4. **Set up** a production-like test environment
5. **Shadow** experienced DSE operators
6. **Contribute** to documentation and runbooks

## 📖 References

- [DSE 6.8 Production Guide](https://docs.datastax.com/en/dse/6.8/managing/)
- [DSE 6.9 Production Guide](https://docs.datastax.com/en/dse/6.9/managing/)
- [DSE 6.8 Security Best Practices](https://docs.datastax.com/en/dse/6.8/managing/security/)
- [DSE 6.9 Security Best Practices](https://docs.datastax.com/en/dse/6.9/managing/security/)
- [DSE 6.8 Capacity Planning](https://docs.datastax.com/en/dse/6.8/managing/operations/opsCapacityPlanning.html)
- [DSE 6.9 Capacity Planning](https://docs.datastax.com/en/dse/6.9/managing/operations/opsCapacityPlanning.html)
- [DSE 6.8 Multi-Datacenter Deployment](https://docs.datastax.com/en/dse/6.8/managing/operations/opsMultiDC.html)
- [DSE 6.9 Multi-Datacenter Deployment](https://docs.datastax.com/en/dse/6.9/managing/operations/opsMultiDC.html)
- [Upgrading DSE 6.8 to 6.9](https://docs.datastax.com/en/upgrading/datastax-enterprise/dse-68-to-69.html)

---

🎉 **Congratulations!** You've completed the DSE 6.8/6.9 Operations Training. You now have the knowledge and skills to operate DSE clusters effectively. Continue practicing and learning!
