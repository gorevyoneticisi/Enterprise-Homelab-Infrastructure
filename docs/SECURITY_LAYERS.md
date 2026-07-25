# Security Layers Overview

Defense-in-depth strategy for homelab security.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    ATTACK SURFACE                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Layer 1: Cloudflare                                   │
│  ├── WAF Custom Rules (path blocking)                 │
│  ├── Bot Fight Mode (ML-based detection)              │
│  ├── DDoS Protection                                   │
│  └── TLS Termination                                   │
│                                                         │
│  Layer 2: CrowdSec                                     │
│  ├── Rate-Limiting Scenarios                           │
│  ├── CVE Detection                                    │
│  ├── SSH Brute Force Protection                       │
│  ├── Cloudflare Bouncer (IP blocking at CF edge)      │
│  └── Firewall Bouncer (iptables blocking)             │
│                                                         │
│  Layer 3: iptables                                     │
│  ├── Service Restriction (SMB, CUPS, MQTT)            │
│  ├── Datacenter IP Blocking                           │
│  ├── Manual Bans                                      │
│  └── Docker DOCKER-USER Chain                         │
│                                                         │
│  Layer 4: Application                                  │
│  ├── IP Ban Middleware (3h bans)                      │
│  ├── CSRF Protection                                  │
│  ├── Bot User-Agent Detection                         │
│  └── Exploit Path Detection                           │
│                                                         │
│  Layer 5: Network                                      │
│  ├── CGNAT (no public IP)                             │
│  ├── WireGuard VPN                                    │
│  └── Tailscale                                         │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Layer Details

### Layer 1: Cloudflare (Edge Protection)

**What:** Blocks attacks before they reach your server.

| Feature | Free | Paid |
|---------|------|------|
| WAF Rules | 5 | Unlimited |
| Bot Fight | Basic | Advanced |
| DDoS | Yes | Yes |
| Rate Limiting | No | Yes |

**Setup:** See `security/cloudflare/waf-setup.md`

### Layer 2: CrowdSec (Intelligence-Based)

**What:** Detects attacks using log analysis and community threat intel.

| Feature | Description |
|---------|-------------|
| Rate-Limiting | Ban IPs exceeding thresholds |
| CVE Detection | Block known exploits |
| SSH Protection | Detect brute force |
| Community Intel | 31K+ known bad IPs |

**Setup:** See `security/crowdsec/rate-limit-scenarios.md`

### Layer 3: iptables (System-Level)

**What:** Kernel-level packet filtering.

| Feature | Description |
|---------|-------------|
| Service Restriction | Limit to LAN/VPN only |
| Datacenter Blocking | Ban cloud provider IPs |
| Manual Bans | Block specific IPs |

**Setup:** See `security/iptables/service-restriction.md`

### Layer 4: Application (Code-Level)

**What:** Protects against bypass attacks.

| Feature | Description |
|---------|-------------|
| IP Ban Middleware | 3h bans for violations |
| CSRF Protection | Prevent cross-site forgery |
| Bot Detection | Block known bots |
| Exploit Detection | Block attack paths |

### Layer 5: Network (Infrastructure)

**What:** Limits attack surface.

| Feature | Description |
|---------|-------------|
| CGNAT | No public IP |
| WireGuard | Encrypted tunnel |
| Tailscale | Mesh VPN |

## Ban Decision Matrix

| IP Type | CrowdSec | iptables | App | Total |
|---------|----------|----------|-----|-------|
| Residential | 10 req/60s | Manual | 5 vio | 1h-24h |
| Datacenter | 5 req/30s | Auto (5) | Auto (1) | 24h-7d |
| Proxy/VPN | 5 req/30s | Auto (3) | Auto (1) | 24h |
| Known Bad | Any | Immediate | Immediate | 7d |

## Monitoring

```bash
# CrowdSec
sudo cscli decisions list --limit 20
sudo cscli alerts list --limit 20

# iptables
sudo iptables -S | grep DROP

# App bans
cat /var/lib/smart-ip-classifier/classified-ips.json | jq .
```

## Emergency Procedures

### Block All Traffic (DDoS)

```bash
sudo iptables -I INPUT -p tcp --dport 80 -j DROP
sudo iptables -I INPUT -p tcp --dport 443 -j DROP
```

### Unblock an IP

```bash
sudo cscli decisions delete --ip X.X.X.X
sudo iptables -D INPUT -s X.X.X.X -j DROP
```

### Flush All Rules (Emergency)

```bash
sudo iptables -F
sudo iptables -X
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT
```
