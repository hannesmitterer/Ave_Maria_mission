#!/bin/bash

###############################################################################
# IPFS File Distribution Script
# 
# Purpose: Automate distributing files (e.g., Peacobonds) across multiple 
#          IPFS nodes with verification and error handling.
#
# Usage: ./distribute_ipfs.sh <file_path> [peers_file]
#   - file_path: Path to the file to distribute (e.g., peacobond_contract.json)
#   - peers_file: Optional path to peers.txt (defaults to ./peers.txt)
#
# Requirements:
#   - IPFS installed (go-ipfs or kubo)
#   - SSH access configured for verification (optional)
###############################################################################

set -e  # Exit on error
set -o pipefail  # Catch errors in pipes

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
LOG_FILE="ipfs_distribution_$(date +%Y%m%d_%H%M%S).log"
IPFS_DAEMON_TIMEOUT=30
PEER_CONNECT_TIMEOUT=10

###############################################################################
# Logging Functions
###############################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"
}

###############################################################################
# Helper Functions
###############################################################################

# Check if IPFS is installed
check_ipfs_installed() {
    if ! command -v ipfs &> /dev/null; then
        log_error "IPFS is not installed. Please install IPFS first."
        log_info "Visit: https://docs.ipfs.tech/install/"
        exit 1
    fi
    log_success "IPFS found at $(which ipfs)"
}

# Check if IPFS daemon is running
is_ipfs_running() {
    ipfs swarm peers &> /dev/null
    return $?
}

# Initialize IPFS repository if needed
initialize_ipfs() {
    log_info "Checking IPFS initialization..."
    
    # Check if IPFS repo exists
    if [ ! -d "$HOME/.ipfs" ]; then
        log_info "IPFS repository not found. Initializing..."
        if ipfs init; then
            log_success "IPFS repository initialized successfully"
        else
            log_error "Failed to initialize IPFS repository"
            exit 1
        fi
    else
        log_success "IPFS repository already initialized"
    fi
}

# Start IPFS daemon if not running
start_ipfs_daemon() {
    log_info "Checking IPFS daemon status..."
    
    if is_ipfs_running; then
        log_success "IPFS daemon is already running"
        return 0
    fi
    
    log_info "Starting IPFS daemon..."
    
    # Start daemon in background
    ipfs daemon > /dev/null 2>&1 &
    local daemon_pid=$!
    
    # Wait for daemon to start
    local counter=0
    while [ $counter -lt $IPFS_DAEMON_TIMEOUT ]; do
        if is_ipfs_running; then
            log_success "IPFS daemon started successfully (PID: $daemon_pid)"
            return 0
        fi
        sleep 1
        counter=$((counter + 1))
    done
    
    log_error "Failed to start IPFS daemon within ${IPFS_DAEMON_TIMEOUT} seconds"
    exit 1
}

# Add file to IPFS and get CID
add_file_to_ipfs() {
    local file_path="$1"
    
    log_info "Adding file to IPFS: $file_path"
    
    # Validate file exists
    if [ ! -f "$file_path" ]; then
        log_error "File not found: $file_path"
        exit 1
    fi
    
    # Add file to IPFS and extract CID
    local output
    local exit_code
    output=$(ipfs add -Q "$file_path" 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        CID="$output"
        log_success "File added to IPFS successfully"
        log_info "CID: $CID"
        echo "$CID"
        return 0
    else
        log_error "Failed to add file to IPFS: $output"
        exit 1
    fi
}

# Read peers from file
read_peers_file() {
    local peers_file="$1"
    
    log_info "Reading peers from: $peers_file"
    
    if [ ! -f "$peers_file" ]; then
        log_error "Peers file not found: $peers_file"
        exit 1
    fi
    
    # Read non-empty, non-comment lines
    PEERS=()
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        line=$(echo "$line" | sed 's/#.*//' | xargs)
        if [ -n "$line" ]; then
            PEERS+=("$line")
        fi
    done < "$peers_file"
    
    if [ ${#PEERS[@]} -eq 0 ]; then
        log_warning "No peers found in $peers_file"
        return 1
    fi
    
    log_success "Found ${#PEERS[@]} peer(s) in $peers_file"
    return 0
}

# Connect to a peer
connect_to_peer() {
    local peer_addr="$1"
    
    log_info "Connecting to peer: $peer_addr"
    
    # Try to connect to peer
    local output
    local exit_code
    output=$(timeout $PEER_CONNECT_TIMEOUT ipfs swarm connect "$peer_addr" 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log_success "Connected to peer: $peer_addr"
        return 0
    else
        log_warning "Failed to connect to peer: $peer_addr"
        log_warning "Error: $output"
        return 1
    fi
}

# Distribute file to peer using bitswap
distribute_to_peer() {
    local peer_addr="$1"
    local cid="$2"
    
    log_info "Distributing file (CID: $cid) to peer..."
    
    # Extract peer ID from multiaddr (using portable sed instead of grep -P)
    # Format: /ip4/192.168.1.1/tcp/4001/p2p/QmPeerID
    local peer_id
    peer_id=$(echo "$peer_addr" | sed -n 's|.*/p2p/\([^/]*\).*|\1|p')
    if [ -z "$peer_id" ]; then
        peer_id=$(echo "$peer_addr" | sed -n 's|.*/ipfs/\([^/]*\).*|\1|p')
    fi
    
    if [ -z "$peer_id" ]; then
        log_warning "Could not extract peer ID from: $peer_addr"
        return 1
    fi
    
    # Trigger bitswap by having the peer fetch the content
    # Note: This relies on the peer actively fetching the content
    # In practice, you'd need SSH or API access to the peer to trigger ipfs pin add
    log_info "File is available for retrieval by peer $peer_id via bitswap"
    log_info "To pin on remote peer, run: ipfs pin add $cid"
    
    return 0
}

# Verify file on peer (requires SSH access)
verify_on_peer() {
    local peer_addr="$1"
    local cid="$2"
    local ssh_host="$3"
    
    if [ -z "$ssh_host" ]; then
        log_info "Skipping verification (SSH host not provided)"
        return 0
    fi
    
    log_info "Verifying file on peer via SSH: $ssh_host"
    log_warning "SSH verification uses relaxed host key checking. Ensure you trust the remote host."
    
    # Try to check if file exists on remote peer
    # Note: Using StrictHostKeyChecking=no for convenience, but be aware this
    # disables host key verification and may expose to MITM attacks.
    # For production use, consider proper SSH key management.
    local output
    local exit_code
    output=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$ssh_host" "ipfs pin ls | grep -q $cid" 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log_success "File verified on peer: $ssh_host"
        return 0
    else
        log_warning "Could not verify file on peer: $ssh_host"
        return 1
    fi
}

# Pin file locally
pin_file_locally() {
    local cid="$1"
    
    log_info "Pinning file locally: $cid"
    
    local output
    local exit_code
    output=$(ipfs pin add "$cid" 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log_success "File pinned locally"
        return 0
    else
        log_error "Failed to pin file locally: $output"
        return 1
    fi
}

###############################################################################
# Main Distribution Logic
###############################################################################

distribute_to_all_peers() {
    local cid="$1"
    local peers_file="$2"
    
    log_info "Starting distribution to all peers..."
    
    # Read peers from file
    if ! read_peers_file "$peers_file"; then
        log_error "Failed to read peers file"
        exit 1
    fi
    
    # Statistics
    local total_peers=${#PEERS[@]}
    local successful_connections=0
    local failed_connections=0
    
    # Connect to each peer and distribute
    for peer_addr in "${PEERS[@]}"; do
        echo ""
        log_info "Processing peer: $peer_addr"
        
        if connect_to_peer "$peer_addr"; then
            successful_connections=$((successful_connections + 1))
            distribute_to_peer "$peer_addr" "$cid"
        else
            failed_connections=$((failed_connections + 1))
        fi
    done
    
    # Summary
    echo ""
    log_info "=========================================="
    log_info "Distribution Summary"
    log_info "=========================================="
    log_info "Total peers: $total_peers"
    log_success "Successful connections: $successful_connections"
    if [ $failed_connections -gt 0 ]; then
        log_warning "Failed connections: $failed_connections"
    fi
    log_info "CID: $cid"
    log_info "=========================================="
}

# Verify all distributions
verify_all() {
    local cid="$1"
    
    log_info "=========================================="
    log_info "Verification Summary"
    log_info "=========================================="
    log_info "CID: $cid"
    log_info "To verify file retrieval, run on any IPFS node:"
    log_info "  ipfs cat $cid"
    log_info "To pin file on any IPFS node, run:"
    log_info "  ipfs pin add $cid"
    log_info "=========================================="
}

###############################################################################
# Usage and Main Entry Point
###############################################################################

show_usage() {
    cat << EOF
Usage: $0 <file_path> [peers_file]

Arguments:
  file_path   Path to the file to distribute (required)
  peers_file  Path to peers.txt file (optional, defaults to ./peers.txt)

Example:
  $0 peacobond_contract.json
  $0 peacobond_contract.json custom_peers.txt

Peers file format (one multiaddr per line):
  /ip4/192.168.1.100/tcp/4001/p2p/QmPeerID1
  /ip4/192.168.1.101/tcp/4001/p2p/QmPeerID2
  # Comments start with #

EOF
}

main() {
    echo ""
    log_info "=========================================="
    log_info "IPFS File Distribution Script"
    log_info "=========================================="
    log_info "Started at: $(date)"
    log_info "Log file: $LOG_FILE"
    echo ""
    
    # Parse arguments
    if [ $# -lt 1 ]; then
        log_error "Missing required argument: file_path"
        show_usage
        exit 1
    fi
    
    local file_path="$1"
    local peers_file="${2:-./peers.txt}"
    
    # Validate inputs
    if [ ! -f "$file_path" ]; then
        log_error "File not found: $file_path"
        exit 1
    fi
    
    # Step 1: Check IPFS installation
    check_ipfs_installed
    
    # Step 2: Initialize IPFS if needed
    initialize_ipfs
    
    # Step 3: Start IPFS daemon if not running
    start_ipfs_daemon
    
    # Step 4: Add file to IPFS and get CID
    local cid
    cid=$(add_file_to_ipfs "$file_path")
    
    # Step 5: Pin file locally
    pin_file_locally "$cid"
    
    # Step 6: Distribute to all peers
    if [ -f "$peers_file" ]; then
        distribute_to_all_peers "$cid" "$peers_file"
    else
        log_warning "Peers file not found: $peers_file"
        log_info "Skipping peer distribution"
    fi
    
    # Step 7: Show verification instructions
    verify_all "$cid"
    
    echo ""
    log_success "Distribution process completed!"
    log_info "Log saved to: $LOG_FILE"
    echo ""
}

# Run main function
main "$@"
