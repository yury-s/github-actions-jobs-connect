#!/bin/bash

echo "Installing required packages..."
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends wireguard openssh-client stun-client nmap netcat-openbsd iproute2

# Check for stun client by hanpfei
STUN=""
[[ "$(command -v stun-client)" ]] && STUN="stun-client"
[[ "$(command -v stun)" ]] && STUN="stun"
if [[ ! "$STUN" ]]; then
  echo "stun client not found, please install 'stun' or 'stun-client' package!"
  exit 3
fi

echo
echo "Current interfaces:"
ip a
echo

# Choose random local source port from 20000-30000 range.
# Linux/Android default local port range is 32768-60999,
# Windows and macOS is 49152-65535.
# Do not use ports from this range to prevent possible
# mapping collision with some rare source-dependent-port-preserving
# NATs.
PORT=$(( 20000 + $RANDOM % 10000 ))

# Run stun client with source port PORT and save its output,
# stun.ekiga.net server with two external IP addresses,
# which is important for receiving proper NAT type information.
STUN_OUTPUT="$("$STUN" stun.ekiga.net -v -p $PORT 2>&1)"

# Extract external IP address and mapped port from stun output.
IPPORT=$(echo "$STUN_OUTPUT" | awk '/MappedAddress/ {print $3; exit}')

echo -n "Your NAT type is: "
echo "$STUN_OUTPUT" | awk '/Primary:/ {print substr($0, index($0, $2)); exit}'
echo

# Random port, host/port dependent mapping NAT would not work unfortunately, as we
# won't be able to determine NAT port mapping for GitHub Actions worker IP address.
if [[ ! $(echo "$STUN_OUTPUT" | grep 'Independent Mapping') ]]; then
  echo "Unfortunately, your NAT type uses random mappings for different destination host/port, which is not compatible"
  echo "with this example. The script will now exit."
  exit 4
fi

echo
echo "client_ip: ${IPPORT%%:*}"
echo "client_mapped_port: ${IPPORT##*:}"
echo "client_source_port: $PORT"

mkdir -p client_config
cat > client_config/CLIENT_IP_PORT <<EOF
CLIENT_IP=${IPPORT%%:*}
CLIENT_PORT=${IPPORT##*:}
CLIENT_SOURCE_PORT=$PORT
EOF

echo "Written client_config/CLIENT_IP_PORT"

if [[ ! $(echo "$STUN_OUTPUT" | grep 'preserves ports') ]]; then
  (
    echo "> Punching NAT in the background"
    while [ 1 ]; do
      echo | nc -w 1 -n -u -p $PORT 3.3.3.3 443
      sleep 1
    done
  ) &
fi
