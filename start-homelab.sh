#!/bin/bash
set -u

BASE=/root/homelab
SERVICES="traefik glance cert-server"

# Start AdGuard first (uses the locally cached image so DNS is available for pulling)
echo "Starting AdGuard..."
cd "$BASE/adguard" || exit 1
docker compose up -d

# Wait for DNS to be ready (critical! image pulls need DNS)
echo "Waiting for AdGuard DNS to be ready..."
sleep 30

# Pull latest images for every service (including AdGuard)
for service in adguard $SERVICES; do
    echo "Pulling latest images for $service..."
    cd "$BASE/$service" || continue
    docker compose pull || echo "WARNING: pull failed for $service, continuing with cached images"
done

# Re-apply AdGuard (recreates the container only if its image changed)
cd "$BASE/adguard" && docker compose up -d

# Start/recreate all other services with the new images
for service in $SERVICES; do
    echo "Starting $service..."
    cd "$BASE/$service" || continue
    docker compose up -d
done

# Remove old, dangling images left behind by updates
docker image prune -f

echo "All homelab services started with latest images."
