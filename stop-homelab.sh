#!/bin/bash

# Stop all other services first
for service in traefik glance netbird; do
    echo "Stopping $service..."
    cd /root/homelab/$service
    docker compose down
done

# Stop AdGuard last
echo "Stopping AdGuard..."
cd /root/homelab/adguard
docker compose down

echo "All homelab services stopped."