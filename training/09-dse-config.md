# Module 09 — DSE-Specific Configuration Tasks

Use **dsetool** for DSE-specific configuration and management tasks that aren't covered by nodetool. This module covers common DSE configuration operations, particularly around security and encryption.

## 🎯 Goals

- 🔐 Understand when to use `dsetool` vs `nodetool`
- 🔑 Use `dsetool encryptconfigvalue` to encrypt sensitive configuration values
- 🔒 Configure internode encryption to secure node-to-node communication
- 📋 Explore other DSE-specific configuration management tasks
- 🛡️ Learn best practices for securing DSE configuration

## 🚀 Running dsetool

From the repo root:

```bash
./scripts/dsetool.sh <command> [args]
```

💡 **To run on another node** (e.g. dse-node-1 or dse-node-2):

```bash
./scripts/dsetool-node.sh dse-node-1 <command> [args]
```

## 🔍 dsetool vs nodetool

**nodetool** covers core Cassandra operations:
- Cluster status and ring management
- Repair, compaction, cleanup
- Table statistics and metrics
- Node lifecycle (decommission, removenode)

**dsetool** covers DSE-specific features:
- Configuration encryption (`encryptconfigvalue`)
- DSE Search (Solr) index management (if Search is enabled)
- DSE Graph operations (if Graph is enabled)
- DSE Analytics/Spark management (if Analytics is enabled)
- System key management (`createsystemkey`)

💡 **For this training**: We focus on core Cassandra operations, so most tasks use `nodetool`. However, `dsetool` is essential for DSE-specific configuration management, especially security-related tasks.

## 🔐 Configuration Encryption

In DataStax Enterprise (DSE), configuration encryption is designed to mask sensitive information—like LDAP passwords, truststore passwords, and JMX credentials—so they aren't stored in plain text within your `dse.yaml` or `cassandra.yaml` files.

The mechanism works by using a **System Key** to encrypt specific values, which DSE then decrypts in memory at runtime. The encrypted values are never written back to disk in plain text.

### Why Encrypt Configuration Values?

- **Security**: Prevents passwords from being visible in config files
- **Compliance**: Meets security requirements for sensitive data
- **Best Practice**: Recommended for production deployments
- **Protection**: Masks LDAP/Active Directory passwords, SSL/TLS keystore/truststore passwords, audit logging credentials, and other sensitive configuration values

### The Encryption Workflow

To encrypt a specific value (e.g., your LDAP password), you don't just type it into the config file. You use a built-in tool:

#### Step 1: Generate the Encrypted String

Run the `dsetool` command to encrypt your plain-text value:

```bash
./scripts/dsetool.sh encryptconfigvalue
```
> Now type in your password (eg: mySecretPassword123)

**Example output:**
```
Encrypted value: +Vj5oHCR/jqfA+OJE2m8zA==
```

💡 **Note**: The encrypted value is a base64-encoded blob. You can encrypt any sensitive string this way.

#### Step 2: Update the Config Files

Paste that encrypted blob directly into your `.yaml` file where the plain-text password used to be:

**In `dse.yaml`:**
```yaml
ldap_options:
    search_password: +Vj5oHCR/jqfA+OJE2m8zA==
```

**In `cassandra.yaml`:**
```yaml
server_encryption_options:
    keystore_password: +Vj5oHCR/jqfA+OJE2m8zA==
```

#### Step 3: Enable the Feature

You must tell DSE to expect encrypted values by setting the activation flag in `dse.yaml`:

```yaml
config_encryption_active: true
config_encryption_key_name: system_key  # The name of your key
```

⚠️ **Critical**: Once `config_encryption_active` is set to `true`, DSE becomes very strict. If you leave a sensitive field in plain text that DSE expects to be encrypted, the node will fail to start. This prevents accidental exposure of secrets during a configuration change.

### How DSE Reads Encrypted Values

When the DSE process starts:

1. **It checks if `config_encryption_active` is `true`** in `dse.yaml`.

2. **It loads the System Key** (from disk for local keys, or from KMIP for remote keys).

3. **As it parses `cassandra.yaml` and `dse.yaml`**, it identifies fields that look like encrypted blobs (base64-encoded strings).

4. **It decrypts them in-memory only**. The values are never written back to disk in plain text.

5. **If a sensitive field is found in plain text** when encryption is enabled, DSE will refuse to start, preventing accidental exposure.

### Fields That Can Be Encrypted

You can encrypt almost any sensitive "password" or "secret" field, including:

- **LDAP/Active Directory**: `search_password`, `truststore_password`
- **SSL/TLS**: `keystore_password`, `truststore_password` (for internode or client communication)
- **Audit Logging**: Destination credentials
- **JMX**: Authentication credentials
- **DSE Search**: Index encryption passwords
- **Any custom password field** in configuration files

**Example configuration with encrypted values:**

**In `dse.yaml`:**
```yaml
config_encryption_active: true
config_encryption_key_name: system_key

ldap_options:
    search_password: +Vj5oHCR/jqfA+OJE2m8zA==  # Encrypted LDAP password
    truststore_password: xYz9AbCdEfGhIjKlMnOpQ==  # Encrypted truststore password
```

**In `cassandra.yaml`:**
```yaml
server_encryption_options:
    keystore_password: aBcDeFgHiJkLmNoPqRsTuV==  # Encrypted keystore password
    truststore_password: wXyZaBcDeFgHiJkLmNoPq==  # Encrypted truststore password
```

### System Keys: The Foundation of Encryption

Before you can encrypt configuration values, you need a **System Key** (also called the "Master" key) to handle encryption and decryption. You have two choices for where this key lives:

#### 1. Local Key (File-Based)

A physical file stored on the disk of every node (usually in `/etc/dse/conf/`). You generate it once and manually copy it to all nodes in the cluster.

**Creating a local system key:**

```bash
# Run on one node (e.g., the seed)
./scripts/dsetool.sh createsystemkey system_key
```

**Example output:**
```
System key 'system_key' created successfully.
Key file location: /etc/dse/conf/system_key
```

**After creation, you must:**

1. **Copy the key to all nodes** in the cluster:
   ```bash
   # From the host (if using Docker/Colima)
   docker cp dse-seed:/etc/dse/conf/system_key ./system_key
   docker cp ./system_key dse-node-1:/etc/dse/conf/system_key
   docker cp ./system_key dse-node-2:/etc/dse/conf/system_key
   ```

2. **Set proper permissions** (inside each container):
   ```bash
   # Open a shell on each node
   ./scripts/shell.sh dse-node-1
   # Inside the container:
   chmod 700 /etc/dse/conf/system_key
   chown dse:dse /etc/dse/conf/system_key
   ```

3. **Verify the key exists** on all nodes before enabling encryption.

💡 **Note**: In a Docker/Colima environment, you'll need to ensure the key persists across container restarts. Consider mounting it as a volume or copying it during container startup.

#### 2. KMIP (Remote Key Management)

DSE fetches the key from a remote Key Management Server (like Vormetric, HyTrust, or AWS KMS via a KMIP proxy). This is more secure as the key never lives on the local disk.

**Configuration in `dse.yaml`:**
```yaml
kmip_hosts:
    host.yourdomain.com:
        hosts: kmip1.yourdomain.com, kmip2.yourdomain.com
        keystore_path: /path/to/keystore.jks
        keystore_password: <encrypted_password>
        truststore_path: /path/to/truststore.jks
        truststore_password: <encrypted_password>
```

💡 **Note**: KMIP setup is more complex and typically used in enterprise environments. For training and development, local keys are simpler to set up.

## 🔒 Internode Encryption

Internode encryption secures communication between DSE nodes in your cluster. It encrypts all traffic between nodes, including gossip, streaming (repair/bootstrap), and replication data.

### Why Enable Internode Encryption?

- 🔐 **Security**: Protects data in transit between nodes from eavesdropping
- 📋 **Compliance**: Required for many regulatory standards (HIPAA, PCI-DSS, GDPR)
- 🌐 **Network Security**: Essential when nodes communicate over untrusted networks
- ✅ **Best Practice**: Recommended for production deployments, especially multi-datacenter setups

### How Internode Encryption Works

DSE uses SSL/TLS to encrypt internode communication. Each node needs:
- 🔑 **Keystore**: Contains the node's certificate and private key (used for authentication)
- 🛡️ **Truststore**: Contains certificates of trusted nodes (used to verify peer identity)

**Communication flow:**
1. 🔌 When nodes connect, they present their certificates from their keystores
2. ✅ Each node verifies the peer's certificate against its truststore
3. 🔒 If verification succeeds, an encrypted TLS connection is established
4. 📡 All subsequent communication (gossip, streaming, replication) flows over this encrypted channel

### Configuring Internode Encryption

Enable internode encryption in `cassandra.yaml`:

```yaml
server_encryption_options:
    internode_encryption: all  # Options: none, all, dc, rack
    keystore: /etc/dse/conf/.keystore
    keystore_password: <encrypted_password>  # Use dsetool encryptconfigvalue
    truststore: /etc/dse/conf/.truststore
    truststore_password: <encrypted_password>  # Use dsetool encryptconfigvalue
    # Optional: specify protocol and algorithm
    protocol: TLS
    algorithm: SunX509
    store_type: JKS
    cipher_suites: [TLS_RSA_WITH_AES_256_CBC_SHA, TLS_RSA_WITH_AES_128_CBC_SHA]
    require_client_auth: true  # Mutual TLS authentication (recommended)
```

**Encryption levels:**

- ❌ **`none`**: No encryption (default, not recommended for production)
- ✅ **`all`**: Encrypt all internode communication (recommended)
- 🌐 **`dc`**: Encrypt only between datacenters (multi-DC clusters)
- 🏗️ **`rack`**: Encrypt only between racks (advanced use cases)

💡 **Recommendation**: Use `all` for maximum security. Use `dc` only if you have a specific requirement to encrypt cross-DC traffic but not within a DC.

### Setting Up Keystores and Truststores

#### Option 1: Self-Signed Certificates (Development/Testing) 🧪

For development or testing, you can generate self-signed certificates:

```bash
# Generate a keystore with a self-signed certificate for each node
keytool -genkeypair -alias dse-node -keyalg RSA -keysize 2048 \
  -storetype JKS -keystore /etc/dse/conf/.keystore \
  -dname "CN=dse-seed,OU=DC1,O=DSE,L=City,ST=State,C=US" \
  -storepass <password> -keypass <password>

# Export the certificate
keytool -exportcert -alias dse-node -file dse-seed.crt \
  -keystore /etc/dse/conf/.keystore -storepass <password>

# Import all node certificates into a truststore (on each node)
keytool -importcert -alias dse-seed -file dse-seed.crt \
  -keystore /etc/dse/conf/.truststore -storepass <password> -noprompt
keytool -importcert -alias dse-node-1 -file dse-node-1.crt \
  -keystore /etc/dse/conf/.truststore -storepass <password> -noprompt
keytool -importcert -alias dse-node-2 -file dse-node-2.crt \
  -keystore /etc/dse/conf/.truststore -storepass <password> -noprompt
```

#### Option 2: CA-Signed Certificates (Production) 🏭

For production, use certificates signed by a Certificate Authority (CA):

1. 📝 **Generate a Certificate Signing Request (CSR)** for each node:
   ```bash
   keytool -certreq -alias dse-node -file dse-seed.csr \
     -keystore /etc/dse/conf/.keystore -storepass <password>
   ```

2. 📤 **Submit CSRs to your CA** and receive signed certificates.

3. 📥 **Import the CA certificate** into each node's truststore:
   ```bash
   keytool -importcert -alias ca-root -file ca-root.crt \
     -keystore /etc/dse/conf/.truststore -storepass <password> -noprompt
   ```

4. ✅ **Import the signed certificate** into each node's keystore:
   ```bash
   keytool -importcert -alias dse-node -file dse-seed-signed.crt \
     -keystore /etc/dse/conf/.keystore -storepass <password>
   ```

### Integrating with Configuration Encryption

Since keystore and truststore passwords are sensitive, encrypt them using `dsetool encryptconfigvalue`:

```bash
# Encrypt the keystore password
./scripts/dsetool.sh encryptconfigvalue "myKeystorePassword123"
# Output: +Vj5oHCR/jqfA+OJE2m8zA==

# Encrypt the truststore password
./scripts/dsetool.sh encryptconfigvalue "myTruststorePassword123"
# Output: xYz9AbCdEfGhIjKlMnOpQ==
```

**Then use the encrypted values in `cassandra.yaml`:**

```yaml
server_encryption_options:
    internode_encryption: all
    keystore: /etc/dse/conf/.keystore
    keystore_password: +Vj5oHCR/jqfA+OJE2m8zA==  # Encrypted
    truststore: /etc/dse/conf/.truststore
    truststore_password: xYz9AbCdEfGhIjKlMnOpQ==  # Encrypted
    require_client_auth: true
```

### Client Encryption vs Internode Encryption

DSE supports two types of encryption:

**Internode Encryption** (`server_encryption_options`):
- 🔗 Encrypts communication **between DSE nodes**
- 📡 Protects gossip, streaming, replication
- ⚙️ Configured in `cassandra.yaml` under `server_encryption_options`

**Client Encryption** (`client_encryption_options`):
- 💻 Encrypts communication **between clients and DSE**
- 🔐 Protects CQL queries and responses
- ⚙️ Configured separately in `cassandra.yaml` under `client_encryption_options`

💡 **Best Practice**: Enable both internode and client encryption in production for comprehensive security.

**Example: Both enabled in `cassandra.yaml`:**

```yaml
# Internode encryption (node-to-node)
server_encryption_options:
    internode_encryption: all
    keystore: /etc/dse/conf/.keystore
    keystore_password: <encrypted_password>
    truststore: /etc/dse/conf/.truststore
    truststore_password: <encrypted_password>
    require_client_auth: true

# Client encryption (client-to-node)
client_encryption_options:
    enabled: true
    keystore: /etc/dse/conf/.client-keystore
    keystore_password: <encrypted_password>
    require_client_auth: false  # Usually false for clients
```

### Verifying Internode Encryption

After enabling internode encryption, verify it's working:

1. 📋 **Check logs** for TLS handshake success:
   ```bash
   ./scripts/shell.sh
   # Inside container:
   grep -i "ssl\|tls" /var/log/cassandra/system.log | tail -20
   ```

2. 📊 **Monitor connections** with `nodetool netstats`:
   ```bash
   ./scripts/nodetool.sh netstats
   ```
   Connections should show as encrypted/TLS.

3. ✅ **Test connectivity**: Nodes should still be able to communicate normally:
   ```bash
   ./scripts/nodetool.sh status
   ```
   All nodes should show **UN** (Up Normal).

### Troubleshooting Internode Encryption

**Common issues:**

- ❌ **"SSL handshake failed"**: Check that certificates are valid, truststores contain peer certificates, and passwords are correct
- 🔍 **"Certificate not found"**: Verify keystore path and alias match configuration
- 🔗 **"Node cannot connect"**: Ensure `internode_encryption` is set to the same value on all nodes
- 🔑 **"Password incorrect"**: Verify encrypted passwords are correct and configuration encryption is properly set up

**Debug steps:**

1. 🔍 Check certificate validity:
   ```bash
   keytool -list -v -keystore /etc/dse/conf/.keystore -storepass <password>
   ```

2. ✅ Verify truststore contains peer certificates:
   ```bash
   keytool -list -v -keystore /etc/dse/conf/.truststore -storepass <password>
   ```

3. 📋 Check DSE logs for SSL/TLS errors:
   ```bash
   ./scripts/shell.sh
   tail -f /var/log/cassandra/system.log | grep -i ssl
   ```

### Best Practices

1. 🏭 **Use CA-signed certificates in production**: Self-signed certificates are fine for development but not for production.

2. 🔐 **Enable mutual authentication**: Set `require_client_auth: true` for internode encryption to ensure both sides authenticate.

3. 🔑 **Encrypt passwords**: Always use `dsetool encryptconfigvalue` for keystore/truststore passwords and enable `config_encryption_active`.

4. 🛡️ **Use strong cipher suites**: Specify modern, secure cipher suites in your configuration.

5. 🔄 **Rotate certificates**: Plan for certificate renewal before expiration (typically annually).

6. 🧪 **Test in non-production first**: Always test encryption configuration changes in a non-production environment.

7. 📊 **Monitor performance**: Encryption adds CPU overhead; monitor node performance after enabling.

## 📋 Other dsetool Commands

### status

Shows DSE-specific status information:

```bash
./scripts/dsetool.sh status
```

This provides information about:
- DSE version and components enabled
- Node roles (database, search, analytics, graph)
- Cluster-wide DSE configuration

### ring

Shows the ring with DSE-specific information:

```bash
./scripts/dsetool.sh ring
```

Similar to `nodetool ring` but may include DSE-specific details.

### DSE Search (Solr) Commands

If DSE Search is enabled, `dsetool` provides commands for managing Solr indexes:

```bash
# List all search indexes
./scripts/dsetool.sh list_core

# Reload a search index
./scripts/dsetool.sh reload_core <keyspace.table>

# Reindex data
./scripts/dsetool.sh reindex_core <keyspace.table>
```

💡 **Note**: These commands are only available when DSE Search is enabled. Our training environment uses the database profile only, so Search is not available.

### DSE Graph Commands

If DSE Graph is enabled, `dsetool` provides commands for graph management:

```bash
# List graphs
./scripts/dsetool.sh list_graphs

# Graph status
./scripts/dsetool.sh graph_status <graph_name>
```

💡 **Note**: These commands are only available when DSE Graph is enabled. Our training environment uses the database profile only, so Graph is not available.

## 🔒 Security Best Practices

1. **Encrypt sensitive values**: Use `dsetool encryptconfigvalue` for passwords, keystore passwords, and other sensitive configuration values.

2. **Enable internode encryption**: Configure SSL/TLS encryption for node-to-node communication in production environments.

3. **Protect system keys**: Store system keys securely with appropriate permissions (700, owned by dse user).

4. **Enable config encryption in production**: Set `config_encryption_active: true` in production environments.

5. **Use CA-signed certificates**: For production internode encryption, use certificates signed by a trusted Certificate Authority.

6. **Rotate keys and certificates periodically**: Plan for key and certificate renewal as part of your security practices.

7. **Limit access**: Restrict access to configuration files, system keys, and keystores to authorized personnel only.

## 🧪 Hands-On Exercises

**Note**: These exercises demonstrate configuration encryption. In a production environment, you would apply encrypted values to actual configuration files and enable `config_encryption_active`.

### 🟢 Beginner: Basic Configuration Encryption

#### Exercise 1: Encrypt a Configuration Value

1. **Encrypt a sample password:**
```bash
./scripts/dsetool.sh encryptconfigvalue "examplePassword123"
```

2. **View the encrypted output** and note the format (base64-encoded string like `+Vj5oHCR/jqfA+OJE2m8zA==`).

3. **Try encrypting different values** to see how the output changes:
```bash
./scripts/dsetool.sh encryptconfigvalue "anotherSecret"
./scripts/dsetool.sh encryptconfigvalue "test123"
```

### 🟡 Intermediate: System Key Management

#### Exercise 2: Create a Local System Key

1. **Create a system key** on the seed node:

```bash
./scripts/dsetool.sh createsystemkey system_key
```

2. **Verify the key was created** (inside the container):

```bash
./scripts/shell.sh
# Inside the container:
ls -la /etc/dse/conf/system_key
# You should see the key file with proper permissions
```

3. **Copy the key to other nodes** (if you have a multi-node cluster):

```bash
# From the host
docker cp dse-seed:/etc/dse/conf/system_key ./system_key
docker cp ./system_key dse-node-1:/etc/dse/conf/system_key
docker cp ./system_key dse-node-2:/etc/dse/conf/system_key
```

3. **Copy the key to other nodes** (if you have a multi-node cluster):

```bash
# From the host
docker cp dse-seed:/etc/dse/conf/system_key ./system_key
docker cp ./system_key dse-node-1:/etc/dse/conf/system_key
docker cp ./system_key dse-node-2:/etc/dse/conf/system_key
```

4. **Set proper permissions** on each node:
```bash
./scripts/shell.sh dse-node-1
# Inside container:
chmod 700 /etc/dse/conf/system_key
chown dse:dse /etc/dse/conf/system_key
```

### 🔴 Advanced: Complete Encryption Workflow

#### Exercise 3: Full Configuration Encryption Setup

1. **Create system key** (if not done): `./scripts/dsetool.sh createsystemkey system_key`
2. **Encrypt multiple passwords**:
   ```bash
   ./scripts/dsetool.sh encryptconfigvalue "keystorePassword123"
   ./scripts/dsetool.sh encryptconfigvalue "truststorePassword123"
   ```
3. **Update configuration files** with encrypted values (create test configs).
4. **Enable encryption**: Set `config_encryption_active: true` in `dse.yaml`.
5. **Verify**: Check that DSE starts correctly with encrypted passwords.

#### Exercise 4: Explore dsetool Commands

1. **Check dsetool status:**

```bash
./scripts/dsetool.sh status
```

2. **Compare with nodetool:**

```bash
./scripts/nodetool.sh status
```

Notice that `dsetool status` provides DSE-specific information, while `nodetool status` focuses on core Cassandra operations.

### Exercise 4: Understanding the Encryption Flow

1. **Without encryption enabled**, DSE accepts plain-text passwords in config files.

2. **After enabling `config_encryption_active: true`**, DSE requires encrypted values for all sensitive fields.

3. **If you forget to encrypt a password** after enabling encryption, DSE will fail to start with an error indicating which field needs to be encrypted.

💡 **Important**: In production, always test configuration changes in a non-production environment first, especially when enabling encryption.

## 📚 When to Use dsetool

Use `dsetool` when you need to:

- ✅ Encrypt configuration values (passwords, keystore passwords)
- ✅ Manage system keys for encryption
- ✅ Work with DSE Search indexes (if Search is enabled)
- ✅ Manage DSE Graph (if Graph is enabled)
- ✅ Manage DSE Analytics/Spark (if Analytics is enabled)
- ✅ View DSE-specific cluster status

Use `nodetool` for:

- ✅ Core Cassandra operations (repair, compaction, status)
- ✅ Table statistics and metrics
- ✅ Node lifecycle management
- ✅ General cluster health monitoring

## 🚀 Next

Go to [10 – Advanced Operations](10-advanced-operations.md) for node decommissioning, removal, and token management.

## 📖 References

- [DSE 6.8 dsetool Documentation](https://docs.datastax.com/en/dse/6.8/managing/tools/dsetool/)
- [DSE 6.9 dsetool Documentation](https://docs.datastax.com/en/dse/6.9/managing/tools/dsetool/)
- [DSE 6.8 Configuration Encryption](https://docs.datastax.com/en/dse/6.8/managing/security/secConfigEncryption.html)
- [DSE 6.9 Configuration Encryption](https://docs.datastax.com/en/dse/6.9/managing/security/secConfigEncryption.html)
- [DSE 6.8 Security Guide](https://docs.datastax.com/en/dse/6.8/managing/security/)
- [DSE 6.9 Security Guide](https://docs.datastax.com/en/dse/6.9/managing/security/)
