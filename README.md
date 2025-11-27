# Homelab Docker Compose Services

Self-hosted services with HTTPS via Traefik reverse proxy, local DNS resolution via AdGuard Home, and trusted SSL certificates using mkcert.

## Services

| Service | Domain | Container IP | Description |
|---------|--------|--------------|-------------|
| **Traefik** | `traefik.local` | 172.20.0.10 | Reverse proxy with automatic HTTPS |
| **AdGuard Home** | `adguard.local` | 172.20.0.11 | DNS server with ad blocking & local DNS rewrites |
| **Glance** | `glance.local` | 172.20.0.12 | Dashboard with service monitoring |
| **NetBird** | (VPN only) | 172.20.0.13 | Private network mesh VPN client |
| **Cert Server** | `cert.local` | 172.20.0.20 | CA certificate download page (nginx) |
| **Proxmox** | `proxmox.local` | External | Hypervisor at 192.168.1.9:8006 |
| **Home Assistant** | `ha.local` | External | Home automation at 192.168.1.100:8123 |

## Architecture

### Network
- Docker network: `homelab` (external, bridge, 172.20.0.0/24)
- All services use static IPs for predictability
- Traefik listens on host ports 80/443 (HTTP/HTTPS) and 8080 (dashboard)
- AdGuard DNS on host port 53 (TCP/UDP)

### HTTPS & Certificates
- **Local CA**: mkcert-generated root CA trusted by devices
- **Certificate**: SAN cert covering all `*.local` domains
- **Location**: `/root/homelab/traefik/data/homelab.pem` + `homelab-key.pem`
- **CA Root**: `/root/homelab/traefik/certs/homelab-ca.crt`
- **Auto-redirect**: All HTTP requests redirect to HTTPS via Traefik entrypoint

### DNS Resolution
- AdGuard provides DNS rewrites mapping all `*.local` → `192.168.1.200` (Traefik host)
- Clients must use AdGuard as DNS server (set via router DHCP or manually)
- Containers inherit DNS from host for external resolution

### Glance Monitor Fix
Glance container needs the CA certificate to monitor HTTPS services:
- CA mounted via volume: `../traefik/certs/homelab-ca.crt`
- Custom entrypoint (`entrypoint.sh`) installs `ca-certificates` package on startup
- CA automatically trusted for internal HTTPS health checks

## Quick Start

### Prerequisites
1. Docker & Docker Compose installed
2. External `homelab` network created:
   ```bash
   docker network create --subnet=172.20.0.0/24 homelab
   ```

### Start All Services
```bash
cd /root/homelab
./start-homelab.sh
```
Services start in order: AdGuard (with 30s DNS readiness wait) → Traefik → Glance → NetBird → Cert-Server

### Stop All Services
```bash
./stop-homelab.sh
```

### Individual Service Management
```bash
cd /root/homelab/<service>
docker compose up -d      # Start
docker compose down       # Stop
docker compose logs -f    # Follow logs
docker compose restart    # Restart
```

## Installing CA Certificate on Devices

All devices on your network need the CA certificate installed to avoid "not secure" warnings.

### Download CA
Visit `https://cert.local` (will show cert warning initially) or:
```bash
# From any device on the network
curl -O http://192.168.1.200:80/homelab-ca.crt
```

### Firefox (All Platforms)
1. Settings → Privacy & Security → Certificates → View Certificates
2. **Authorities** tab → **Import**
3. Select `homelab-ca.crt`
4. Check **"Trust this CA to identify websites"**
5. Restart Firefox

**Note**: Firefox uses its own trust store and ignores OS trust by default.

### Windows
```powershell
# Method 1: GUI
# Double-click homelab-ca.crt → Install Certificate
# Store Location: Local Machine → Trusted Root Certification Authorities

# Method 2: Command line
certutil -addstore -f Root homelab-ca.crt
```

### macOS
```bash
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain homelab-ca.crt
```

### Linux
```bash
sudo cp homelab-ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

### iOS/iPadOS
1. Download `homelab-ca.crt` in Safari (tap download link at `cert.local`)
2. Settings → General → VPN & Device Management
3. Tap the certificate profile → Install
4. Settings → General → About → **Certificate Trust Settings**
5. Enable full trust for "mkcert root@docker"

### Android
1. Download `homelab-ca.crt`
2. Settings → Security → Encryption & credentials
3. **Install a certificate** → **CA certificate**
4. Select downloaded file

## DNS Configuration

### For Individual Devices
Set DNS server to `192.168.1.200` (your Docker host IP):
- **iOS/Android**: Wi-Fi settings → Configure DNS → Manual → Add `192.168.1.200`
- **Windows**: Network adapter settings → IPv4 Properties → Preferred DNS
- **macOS**: System Settings → Network → DNS Servers → Add `192.168.1.200`

### For Entire Network (Recommended)
Configure router DHCP to distribute AdGuard as primary DNS:
1. Log into router admin (usually `192.168.1.1`)
2. Find DHCP Server settings
3. Set **Primary DNS**: `192.168.1.200`
4. Restart router or renew DHCP leases on devices

All devices will automatically use AdGuard for DNS without manual configuration.

## File Structure

```
homelab/
├── adguard/
│   ├── docker-compose.yml
│   ├── conf/
│   │   └── AdGuardHome.yaml       # Config with DNS rewrites
│   └── work/                      # Query logs, filter cache
│
├── traefik/
│   ├── docker-compose.yml
│   ├── data/
│   │   ├── dynamic-config.yml     # External service routes (Proxmox, HA)
│   │   ├── homelab.pem            # TLS certificate (active)
│   │   └── homelab-key.pem        # TLS private key (active)
│   ├── certs/
│   │   ├── homelab-ca.crt         # CA root certificate (for downloads)
│   │   └── index.html             # CA installation instructions page
│   └── logs/                      # (empty - stdout logging used)
│
├── glance/
│   ├── docker-compose.yml
│   ├── entrypoint.sh              # CA installation wrapper
│   └── config/
│       └── glance.yml             # Dashboard & monitor config
│
├── netbird/
│   ├── docker-compose.yml
│   ├── config/                    # NetBird client config
│   └── data/                      # VPN connection state
│
├── cert-server/
│   └── docker-compose.yml         # Nginx serving CA download page
│
├── start-homelab.sh               # Start all services
├── stop-homelab.sh                # Stop all services
└── README.md                      # This file
```

## Certificate Management

### Certificate Details
- **Issuer**: mkcert development CA (mkcert root@docker)
- **Valid Until**: February 26, 2028
- **Domains**: traefik.local, adguard.local, glance.local, proxmox.local, ha.local, cert.local

### Viewing Certificate
```bash
openssl x509 -in /root/homelab/traefik/data/homelab.pem -noout -text
```

### Renewing Certificate
When approaching expiration (or to add domains):
```bash
cd /root/homelab/traefik/data
mkcert -cert-file homelab.pem -key-file homelab-key.pem \
  traefik.local adguard.local glance.local proxmox.local ha.local cert.local \
  <additional-domain>.local
  
cd /root/homelab/traefik && docker compose restart
```

### Adding New Domains
1. Generate new cert with additional domain (see above)
2. Add DNS rewrite in AdGuard:
   - Web UI: Settings → DNS Settings → DNS Rewrites → Add
   - Or edit `/root/homelab/adguard/conf/AdGuardHome.yaml`:
     ```yaml
     rewrites:
       - domain: newservice.local
         answer: 192.168.1.200
     ```
3. Restart AdGuard: `cd /root/homelab/adguard && docker compose restart`
4. Add service to docker-compose with Traefik labels

## Access Patterns

### Via HTTPS Domains (Recommended)
All services accessible at `https://<service>.local`:
- `https://traefik.local` - Traefik dashboard
- `https://adguard.local` - AdGuard admin UI
- `https://glance.local` - Homepage dashboard
- `https://cert.local` - CA download page

### Direct Access (Emergency/Debugging)
- Traefik dashboard: `http://192.168.1.200:8080` (insecure mode, no auth)
- No other services expose host ports (security best practice)

## Troubleshooting

### "Not Secure" / Certificate Warnings
**Cause**: CA certificate not installed in browser/OS trust store

**Solution**:
1. Visit `https://cert.local` and download `homelab-ca.crt`
2. Install CA per platform instructions above
3. **Firefox users**: Must import to Firefox specifically (doesn't use OS trust)
4. Restart browser after install

### Domain Not Resolving
**Cause**: Device not using AdGuard for DNS

**Check**:
```bash
# iOS/Android: Use DNS lookup app
# Windows: 
nslookup glance.local
# macOS/Linux:
dig glance.local @192.168.1.200
```

**Solution**:
1. Verify device DNS settings show `192.168.1.200`
2. Flush DNS cache:
   - Windows: `ipconfig /flushdns`
   - macOS: `sudo dscacheutil -flushcache`
   - Linux: `sudo systemd-resolve --flush-caches`
3. Reconnect to Wi-Fi or renew DHCP lease

### Service Unreachable via HTTPS
**Check Traefik routing**:
```bash
docker logs traefik | grep -i error
curl -H "Host: glance.local" http://192.168.1.200
```

**Check container network**:
```bash
docker inspect glance | grep -i network
```

**Test internal routing**:
```bash
docker exec traefik wget -O- http://glance:8080
```

### Glance Monitor Shows x509 Errors
**Cause**: Container can't validate HTTPS certificates

**Solution**: Already fixed via `entrypoint.sh` wrapper. If issues persist:
```bash
cd /root/homelab/glance
docker compose down && docker compose up -d
docker logs glance  # Should show CA installation
```

### AdGuard DNS Not Working
**Check AdGuard is running**:
```bash
docker ps | grep adguard
docker logs adguard
```

**Check port 53 is accessible**:
```bash
sudo netstat -tuln | grep :53
```

**Verify rewrites configured**:
```bash
grep -A 10 "rewrites:" /root/homelab/adguard/conf/AdGuardHome.yaml
```

### Can't Access from Phone
**Common causes**:
1. **Private DNS enabled**: Android/iOS may override network DNS with DoH provider
   - Android: Settings → Network → Private DNS → Off
   - iOS: Check for DNS profiles in VPN & Device Management
2. **Guest network isolation**: Some routers isolate guest Wi-Fi from LAN
3. **Firewall**: Host firewall blocking port 53/80/443
   ```bash
   sudo ufw status  # Check if enabled
   sudo iptables -L INPUT -n  # Check rules
   ```

## Security Notes

- **Traefik dashboard**: Runs in insecure mode (no auth). Secure with middleware if exposed beyond LAN.
- **AdGuard admin**: Password-protected (user: 01xq). Change default if needed.
- **No host port mappings**: Services only accessible via Traefik (except DNS). Reduces attack surface.
- **TLS everywhere**: HTTP auto-redirects to HTTPS. All internal traffic encrypted.
- **CA certificate**: Only trusted locally. Valid only for listed SAN domains. Not publicly trusted.

## Maintenance

### Updating Services
```bash
cd /root/homelab/<service>
docker compose pull
docker compose up -d
```

### Viewing Logs
```bash
# All logs
docker compose logs -f

# Specific service
docker logs -f traefik
docker logs --tail 100 adguard
```

### Backup Important Data
```bash
# AdGuard config & query logs
tar -czf adguard-backup.tar.gz adguard/conf adguard/work

# Glance config
tar -czf glance-backup.tar.gz glance/config

# Traefik certificates
tar -czf traefik-certs-backup.tar.gz traefik/data/*.pem traefik/certs/*.crt
```

### Clean Up Unused Resources
```bash
docker system prune -a --volumes  # WARNING: Removes all unused images/volumes
```

## Advanced Configuration

### Adding a New Service

1. **Create service directory**:
   ```bash
   mkdir -p /root/homelab/newservice
   cd /root/homelab/newservice
   ```

2. **Create docker-compose.yml**:
   ```yaml
   services:
     newservice:
       image: example/service
       container_name: newservice
       restart: unless-stopped
       networks:
         homelab:
           ipv4_address: 172.20.0.21  # Pick unused IP
       labels:
         - "traefik.enable=true"
         - "traefik.http.routers.newservice.rule=Host(`newservice.local`)"
         - "traefik.http.routers.newservice.entrypoints=websecure"
         - "traefik.http.routers.newservice.tls=true"
         - "traefik.http.services.newservice.loadbalancer.server.port=8080"
   
   networks:
     homelab:
       external: true
   ```

3. **Add DNS rewrite** (edit `/root/homelab/adguard/conf/AdGuardHome.yaml`):
   ```yaml
   rewrites:
     - domain: newservice.local
       answer: 192.168.1.200
   ```

4. **Regenerate certificate** (if you want a clean cert):
   ```bash
   cd /root/homelab/traefik/data
   mkcert -cert-file homelab.pem -key-file homelab-key.pem \
     traefik.local adguard.local glance.local proxmox.local ha.local cert.local newservice.local
   ```

5. **Update start/stop scripts**:
   ```bash
   # Edit start-homelab.sh and stop-homelab.sh
   # Add "newservice" to the services loop
   ```

6. **Start everything**:
   ```bash
   ./start-homelab.sh
   ```

### Using Custom Domain (.home.arpa instead of .local)
The `.local` TLD is reserved for mDNS/Bonjour. For better standards compliance, use `.home.arpa`:

1. Update all DNS rewrites in AdGuard config
2. Regenerate certificates with new domains
3. Update all Traefik labels in docker-compose files
4. Update Glance monitor URLs

---

**Setup Date**: November 26, 2025  
**Last Updated**: November 27, 2025  
**Maintainer**: 01xq
