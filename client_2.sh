#!/bin/bash

echo "Current interfaces:"
ip a

echo
echo "WireGuard status:"
wg show
echo

echo "Running pinging process:"
pgrep -fl client_1.sh

while pgrep -f client_1.sh; do
  echo "Killing pinging process..."
  # Kill pinging process to avoid
  # RTNETLINK answers: Address already in use
  pkill -f client_1.sh || true
done

echo "Connecting to the server..."
wg-quick up server_config/wg0.conf

echo "Downloading test page from the server..."
# Wait for server to be ready
until curl -sSf --connect-timeout 2 http://192.168.166.1:8080 >/dev/null; do
  sleep 0.2
done
curl http://192.168.166.1:8080/test.html