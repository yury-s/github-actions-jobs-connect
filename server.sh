#!/bin/bash

# Exit on any error
set -e

# Function to print usage
print_usage() {
    echo "Usage: $0 <client_ip> <client_mapped_port> [client_source_port]"
    echo
    echo "Parameters:"
    echo "  client_ip           - Client's external IP address"
    echo "  client_mapped_port  - Client's external port (after NAT mapping)"
    echo "  client_source_port  - Optional: Client's source port (before NAT mapping)"
    echo "                        If not specified, will use client_mapped_port"
    exit 1
}

# Check if GITHUB_ACTIONS is set
if [ -n "$GITHUB_ACTIONS" ]; then
    echo "Waiting for an artifact with client IP address and port mapping ..."
else
    while [ ! -f /mnt/host/CLIENT_IP_PORT ]; do
        echo "Waiting for the CLIENT_IP_PORT file to be created..."
        sleep 1
    done
    source /mnt/host/CLIENT_IP_PORT
    rm -f /mnt/host/CLIENT_IP_PORT
    # Check parameters
    # if [ $# -lt 2 ]; then
    #     print_usage
    # fi

    # CLIENT_IP="$1"
    # CLIENT_PORT="$2"
    # CLIENT_SOURCE_PORT="${3:-$CLIENT_PORT}"
fi

echo "Client IP address: $CLIENT_IP"
echo "Client port (after NAT mapping): $CLIENT_PORT"
echo "Client port (before NAT mapping): $CLIENT_SOURCE_PORT"

# Install required packages if not present
if ! command -v wireguard &> /dev/null || ! command -v stun-client &> /dev/null || ! command -v nmap &> /dev/null; then
    echo "Installing required packages..."
    DEBIAN_FRONTEND=noninteractive apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends wireguard openssh-server stun-client nmap netcat-openbsd iproute2
fi

# Use STUN to detect server's external IP and port mapping
echo "Detecting server's external IP and port mapping..."
STUN_OUTPUT=$(stun -v stun.l.google.com:19302 -p 443 1 2>&1)
echo "$STUN_OUTPUT"
SERVER_IP=$(echo "$STUN_OUTPUT" | awk '/MappedAddress/ {split($0, aport, /:/); split(aport[1], aip, / /); print aip[3]}')
SERVER_PORT=$(echo "$STUN_OUTPUT" | awk '/MappedAddress/ {split($0, aport, /:/); print aport[2]}')

echo "Server IP address: $SERVER_IP"
echo "Server port map for source port 443: $SERVER_PORT"

# Start NAT punching in background
echo "Starting NAT punching..."
nping --udp --ttl 4 --no-capture --source-port 443 --count 0 --delay 28s \
    --dest-port "$CLIENT_PORT" "$CLIENT_IP" &
NPING_PID=$!

# Trap to kill background processes on exit
trap 'kill $NPING_PID 2>/dev/null' EXIT



# Generate WireGuard keys
echo "Generating WireGuard keys..."
SERVER_PRIVATE_KEY=$(wg genkey)
SERVER_PUBLIC_KEY=$(echo "$SERVER_PRIVATE_KEY" | wg pubkey)
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)

# Configure WireGuard interface
echo "Configuring WireGuard interface..."
ip link add dev wg0 type wireguard
ip address add dev wg0 192.168.166.1/30
wg set wg0 listen-port 443 private-key <(echo "$SERVER_PRIVATE_KEY") \
    peer "$CLIENT_PUBLIC_KEY" allowed-ips 192.168.166.2/32

# Start WireGuard
echo "Starting WireGuard..."
ip link set dev wg0 up

echo "WireGuard is running. Press Ctrl+C to stop."


# Start SSH server
# echo "Starting sshd..."
# mkdir -p /var/run/sshd
# /usr/sbin/sshd
# echo "SSH server is running. You can connect to it using:"
# echo "ssh root@192.168.166.1"

# Generate and print client configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIREGUARD_CONFIG="$SCRIPT_DIR/wg0.conf"

cat > $WIREGUARD_CONFIG << EOF
[Interface]
ListenPort = $CLIENT_SOURCE_PORT
Address = 192.168.166.2/30
PrivateKey = $CLIENT_PRIVATE_KEY

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_IP:$SERVER_PORT
AllowedIPs = 192.168.166.1/32
PersistentKeepalive = 25
EOF

echo
echo "Connect client: wg-quick up ${WIREGUARD_CONFIG}"
echo "Do not forget to disconnect with: wg-quick down ${WIREGUARD_CONFIG}"
echo

echo "Starting HTTP server http://192.168.166.1"
npx -y http-server /mnt/host

# Keep script running
while true; do
    sleep 1
done 