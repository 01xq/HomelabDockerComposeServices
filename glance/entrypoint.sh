#!/bin/sh
set -e

# Install CA if not already present
if [ ! -f /etc/ssl/certs/ca-cert-homelab-ca.pem ]; then
    apk add --no-cache ca-certificates >/dev/null 2>&1
    update-ca-certificates >/dev/null 2>&1
fi

# Run the original Glance app with config
exec /app/glance --config /app/config/glance.yml
