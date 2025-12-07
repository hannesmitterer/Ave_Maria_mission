# IPFS File Distribution Script

This directory contains scripts and tools for distributing files across multiple IPFS nodes, ensuring persistent and decentralized storage of important documents like Peacobonds, humanitarian contracts, and mission-critical data.

## Overview

The `distribute_ipfs.sh` script automates the process of:
1. Initializing and starting an IPFS daemon
2. Adding files to IPFS and obtaining their Content Identifier (CID)
3. Connecting to multiple IPFS peer nodes
4. Distributing files across the network using bitswap
5. Verifying file availability

## Prerequisites

### 1. Install IPFS

You need to have IPFS (Kubo) installed on your system:

**Linux/macOS:**
```bash
# Download and install using the official install script
wget https://dist.ipfs.tech/kubo/v0.24.0/kubo_v0.24.0_linux-amd64.tar.gz
tar -xvzf kubo_v0.24.0_linux-amd64.tar.gz
cd kubo
sudo bash install.sh
```

**Or using package managers:**
```bash
# macOS with Homebrew
brew install ipfs

# Ubuntu/Debian
sudo snap install ipfs
```

Verify installation:
```bash
ipfs --version
```

### 2. Configure IPFS (First Time Only)

Initialize your IPFS repository:
```bash
ipfs init
```

This creates a local IPFS repository at `~/.ipfs/`.

### 3. Optional: SSH Access for Verification

If you want to verify files on remote peers, ensure SSH access is configured:
```bash
# Test SSH connection
ssh user@remote-peer-host
```

## Usage

### Basic Usage

```bash
# Distribute a file using default peers.txt
./distribute_ipfs.sh peacobond_contract.json

# Distribute a file using custom peers file
./distribute_ipfs.sh peacobond_contract.json custom_peers.txt
```

### Configuration

#### Peers Configuration (`peers.txt`)

Create a `peers.txt` file with one IPFS multiaddr per line:

```text
# Example peers.txt
/ip4/192.168.1.100/tcp/4001/p2p/QmPeerID1
/ip4/192.168.1.101/tcp/4001/p2p/QmPeerID2
/dns4/peer.example.com/tcp/4001/p2p/QmPeerID3
```

**Getting Peer Multiaddrs:**

To get your own node's multiaddr:
```bash
ipfs id
```

This will show your peer ID and listening addresses. Share these with other nodes.

**Format:**
- IP-based: `/ip4/<IP_ADDRESS>/tcp/<PORT>/p2p/<PEER_ID>`
- DNS-based: `/dns4/<DOMAIN>/tcp/<PORT>/p2p/<PEER_ID>`
- Comments start with `#`
- Empty lines are ignored

### Finding Peers

1. **Local Network Peers:**
   ```bash
   # Discover peers on your local network
   ipfs swarm peers
   ```

2. **Bootstrap Nodes:**
   The script includes public IPFS bootstrap nodes by default for testing.

3. **Custom Peers:**
   Contact other IPFS node operators and exchange multiaddrs.

## Script Features

### 1. Automatic Initialization
- Checks if IPFS is installed
- Initializes IPFS repository if needed
- Starts IPFS daemon if not running

### 2. File Distribution
- Adds files to IPFS with CID generation
- Pins files locally for persistence
- Connects to each peer in the peers list
- Uses bitswap protocol for content distribution

### 3. Error Handling
- Graceful handling of connection failures
- Timeout protection for long operations
- Detailed error logging
- Continues with remaining peers if one fails

### 4. Logging
- Creates timestamped log files
- Color-coded console output
- Detailed operation tracking
- Distribution statistics

### 5. Verification
- Provides verification instructions
- Optional SSH-based verification
- CID output for manual verification

## Examples

### Example 1: Distributing a Peacobond Contract

```bash
cd scripts
./distribute_ipfs.sh peacobond_contract.json
```

Output:
```
[INFO] IPFS File Distribution Script
[INFO] Adding file to IPFS: peacobond_contract.json
[SUCCESS] File added to IPFS successfully
[INFO] CID: QmXxxxx...
[INFO] Connecting to peer: /ip4/192.168.1.100/tcp/4001/p2p/QmPeer1
[SUCCESS] Connected to peer
[INFO] Distribution process completed!
```

### Example 2: Using Custom Peers File

```bash
./distribute_ipfs.sh important_document.pdf my_peers.txt
```

### Example 3: Verifying Distribution

After distribution, verify the file on any IPFS node:

```bash
# View the file
ipfs cat QmXxxxx...

# Pin the file permanently
ipfs pin add QmXxxxx...

# Check file details
ipfs object stat QmXxxxx...
```

## Advanced Usage

### Running IPFS Daemon Manually

If you prefer to manage the daemon yourself:

```bash
# Start daemon in background
ipfs daemon &

# Check status
ipfs swarm peers

# Run distribution script
./distribute_ipfs.sh file.json
```

### Pinning on Remote Peers

The script connects to peers and makes content available via bitswap. To pin content on remote peers, you need to:

**Option 1: SSH Access**
```bash
ssh user@remote-peer "ipfs pin add QmCID..."
```

**Option 2: IPFS API**
```bash
curl -X POST "http://remote-peer:5001/api/v0/pin/add?arg=QmCID..."
```

**Option 3: Manual**
Share the CID with remote node operators and ask them to run:
```bash
ipfs pin add QmCID...
```

### Custom Configuration

Edit the script variables at the top for custom timeouts:

```bash
IPFS_DAEMON_TIMEOUT=30        # Seconds to wait for daemon start
PEER_CONNECT_TIMEOUT=10       # Seconds to wait for peer connection
```

## Troubleshooting

### Problem: "IPFS is not installed"
**Solution:** Install IPFS following the prerequisites section.

### Problem: "Failed to start IPFS daemon"
**Solution:** 
- Check if another daemon is running: `ps aux | grep ipfs`
- Try starting manually: `ipfs daemon`
- Check IPFS logs: `tail ~/.ipfs/logs/*`

### Problem: "Failed to connect to peer"
**Solution:**
- Verify peer multiaddr is correct
- Check firewall settings (port 4001 must be open)
- Ensure peer is online: `ipfs ping <PEER_ID>`
- Check network connectivity

### Problem: "File not found on peer"
**Solution:**
- Wait a few moments for bitswap to propagate
- Manually pin on remote peer: `ipfs pin add <CID>`
- Verify peer connection: `ipfs swarm peers | grep <PEER_ID>`

### Problem: Permission Denied
**Solution:**
```bash
chmod +x distribute_ipfs.sh
```

## Log Files

Each run creates a timestamped log file:
```
ipfs_distribution_YYYYMMDD_HHMMSS.log
```

View recent logs:
```bash
tail -f ipfs_distribution_*.log
```

## Security Considerations

1. **Network Security:**
   - IPFS operates on port 4001 (default)
   - Ensure firewall rules allow IPFS traffic
   - Consider VPN for private networks

2. **Data Privacy:**
   - All content added to IPFS is public by default
   - Use encryption for sensitive data before uploading
   - Consider private IPFS networks for confidential content

3. **SSH Security:**
   - The script uses `StrictHostKeyChecking=no` for SSH verification convenience
   - **WARNING:** This disables host key verification and may expose to man-in-the-middle attacks
   - For production use, configure proper SSH key management:
     - Add host keys to `~/.ssh/known_hosts` before running verification
     - Use SSH key-based authentication (not passwords)
     - Consider removing the `-o StrictHostKeyChecking=no` option
   - Restrict SSH access with proper firewall rules and fail2ban

## Files in This Directory

- `distribute_ipfs.sh` - Main distribution script
- `peers.txt` - Example peer configuration file
- `peacobond_contract.json` - Example Peacobond contract for distribution
- `README.md` - This documentation file

## Integration with Ave Maria Mission

This IPFS distribution system is designed to support the Ave Maria Mission's humanitarian work in South Sudan by:

1. **Decentralized Storage:** Ensuring critical documents (Peacobonds, water allocation plans, operational data) are stored across multiple nodes
2. **Resilience:** Preventing single points of failure in document storage
3. **Transparency:** Making humanitarian contracts and reports permanently accessible
4. **Verification:** Allowing stakeholders to verify document authenticity via CID

## Additional Resources

- [IPFS Documentation](https://docs.ipfs.tech/)
- [IPFS Command Reference](https://docs.ipfs.tech/reference/cli/)
- [Understanding CIDs](https://docs.ipfs.tech/concepts/content-addressing/)
- [IPFS Best Practices](https://docs.ipfs.tech/concepts/best-practices/)

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review IPFS documentation
3. Check log files for detailed error messages
4. Verify network connectivity and firewall settings

## License

This script is part of the Ave Maria Mission project. See the main repository LICENSE file for details.
