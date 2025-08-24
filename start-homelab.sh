#!/bin/bash

# Start AdGuard first
cd /root/homelab/adguard
docker compose up -d

# Wait for DNS to be ready (critical!)
echo "Waiting for AdGuard DNS to be ready..."
sleep 30

# Start all other services
for service in traefik glance netbird; do
    cd /root/homelab/$service
    docker compose up -d
done