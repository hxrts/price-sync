#!/bin/bash

# Retrieve the system hostname
HOSTNAME=$(hostname)

# Get the full path to mix and iex
MIX_PATH=$(which mix)
IEX_PATH=$(which iex)

# Clean and compile first
$MIX_PATH do clean, compile
#$MIX_PATH local.hex --force

# Start the nodes in background processes
$IEX_PATH --sname node_a@$HOSTNAME -S mix &
$IEX_PATH --sname node_b@$HOSTNAME -S mix &
$IEX_PATH --sname node_c@$HOSTNAME -S mix &

# Wait for nodes to start
sleep 5

# Connect the nodes
for NODE in node_a node_b node_c; do
  for TARGET in node_a node_b node_c; do
    if [ "$NODE" != "$TARGET" ]; then
      echo "Node.connect(:${TARGET}@${HOSTNAME})" | $IEX_PATH --sname ${NODE}@${HOSTNAME} -S mix
    fi
  done
done

# Wait for some activity
sleep 10

# Verify the system by checking prices
for NODE in node_a node_b node_c; do
  echo "PriceSync.PriceServer.get_price()" | $IEX_PATH --sname ${NODE}@${HOSTNAME} -S mix
done

# Allow time for divergence checks
sleep 10

# Stop the nodes
pkill -f "node_a@"
pkill -f "node_b@"
pkill -f "node_c@"

echo "Test completed. Nodes have been started, connected, monitored, and terminated."
