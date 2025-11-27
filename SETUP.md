# Initial Setup Guide

This guide covers the initial setup steps needed after cloning this repository.

## Prerequisites

1. **Docker & Docker Compose** installed
2. **mkcert** installed for generating local certificates
3. A Linux host with static IP on your network

## Step 1: Create Docker Network

```bash
docker network create --subnet=172.20.0.0/24 homelab
```

## Step 2: Generate SSL Certificates

```bash
# Install mkcert if not already installed
curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64"
chmod +x mkcert-v*-linux-amd64
sudo mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert

# Create local CA
mkcert -install

# Generate certificates for your services
cd traefik/data
mkcert -cert-file homelab.pem -key-file homelab-key.pem \
  traefik.local adguard.local glance.local proxmox.local ha.local cert.local

# Copy CA certificate for distribution
cp "$(mkcert -CAROOT)/rootCA.pem" ../certs/homelab-ca.crt
```

## Step 3: Create Configuration Files

### Traefik Dynamic Config

```bash
cd traefik/data
cp dynamic-config.yml.example dynamic-config.yml
# Edit dynamic-config.yml and replace YOUR_*_IP placeholders with actual IPs
```

### Service Environment Files

Create `.env` files for services that need them:

**glance/.env**:
```bash
HA_IP=http://YOUR_HOME_ASSISTANT_IP:8123
ADGUARD_IP=http://YOUR_ADGUARD_IP
```

**netbird/.env**:
```bash
NB_SETUP_KEY=your-netbird-setup-key-here
```

## Step 4: Update IP Addresses

Update these files with your actual Docker host IP:

1. `adguard/conf/AdGuardHome.yaml` - DNS rewrites (replace 192.168.1.200)
2. `traefik/data/dynamic-config.yml` - External service IPs
3. All references in README.md if you customize

## Step 5: Start Services

```bash
chmod +x start-homelab.sh stop-homelab.sh
./start-homelab.sh
```

## Step 6: Configure DNS

### Router-Wide (Recommended)
1. Log into your router
2. Set DHCP Primary DNS to your Docker host IP
3. Restart router or renew DHCP leases

### Per-Device
Set DNS manually to your Docker host IP in device network settings.

## Step 7: Install CA Certificate

Visit `https://cert.local` from each device and follow installation instructions.

See main README.md for detailed platform-specific instructions.

## Security Notes

- The `.gitignore` excludes all sensitive files:
  - SSL certificates (*.pem, *.crt, *.key)
  - Environment files with secrets (.env)
  - Configuration files with IPs/passwords (conf/, config/)
  - Runtime data (data/, work/, logs/)

- **Never commit**:
  - Your actual certificates
  - Your `.env` files
  - Your `dynamic-config.yml` with real IPs
  - AdGuard config (contains admin password hash)

## Troubleshooting

If services don't start or aren't accessible, check:
1. Docker network exists: `docker network ls | grep homelab`
2. Certificates exist: `ls traefik/data/*.pem`
3. Config files created: `ls traefik/data/dynamic-config.yml`
4. Services running: `docker ps`
5. Logs: `docker compose logs -f` in each service directory

For detailed troubleshooting, see main README.md.
