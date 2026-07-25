# Smart IP Blocking System

Intelligent IP classification and banning using CrowdSec + ip-api.com.

## Architecture

```
CrowdSec Alerts → ip-api.com Classification → iptables Bans
                         ↓
              ┌─────────────────────┐
              │  Ban Decision Logic │
              ├─────────────────────┤
              │ Residential: 10 vio │→ 1h ban
              │ Datacenter: 5 vio   │→ 24h ban
              │ Proxy/VPN: 3 vio    │→ 24h ban
              │ Known bad: 1 vio    │→ 24h ban
              └─────────────────────┘
```

## Components

### 1. Smart IP Classifier (`smart-ip-classifier.sh`)

Runs every 30 minutes via cron. Classifies IPs using ip-api.com:

```bash
# Check IP classification
GEO=$(curl -s "http://ip-api.com/json/$IP?fields=status,isp,org,as,hosting,proxy")
```

**Classification:**
- `hosting: true` → Datacenter IP
- `proxy: true` → Proxy/VPN IP
- Otherwise → Residential IP

### 2. AI Scraper Blocker (`block-ai-scrapers.sh`)

Runs every 6 hours. Blocks known AI scraper user agents:

```
GPTBot|ChatGPT-User|CCBot|Bytespider|Google-Extended|
anthropic-ai|ClaudeBot|FacebookBot|PerplexityBot
```

### 3. Datacenter IP Blocker (`block-datacenter-ips.sh`)

Runs every 12 hours. Checks all IPs from last 24h and bans datacenter IPs for 7 days.

## Installation

```bash
# Copy scripts
sudo cp smart-ip-classifier.sh /usr/local/bin/
sudo cp block-ai-scrapers.sh /usr/local/bin/
sudo cp block-datacenter-ips.sh /usr/local/bin/

# Make executable
sudo chmod +x /usr/local/bin/smart-ip-classifier.sh
sudo chmod +x /usr/local/bin/block-ai-scrapers.sh
sudo chmod +x /usr/local/bin/block-datacenter-ips.sh

# Install cron jobs
(crontab -l 2>/dev/null; echo "*/30 * * * * /usr/local/bin/smart-ip-classifier.sh") | crontab -
(crontab -l 2>/dev/null; echo "0 */6 * * * /usr/local/bin/block-ai-scrapers.sh") | crontab -
(crontab -l 2>/dev/null; echo "0 */12 * * * /usr/local/bin/block-datacenter-ips.sh") | crontab -
```

## IP Intelligence Sources

| Source | Rate Limit | Data | Cost |
|--------|-----------|------|------|
| ip-api.com | 45 req/min | ISP, org, hosting, proxy | Free |
| CrowdSec CTI | 120/month | Threat scores, classifications | Free tier |
| MaxMind GeoLite2 | Unlimited | Country, ASN | Free (registration) |

## Manual IP Management

```bash
# Ban an IP
sudo cscli decisions add --ip X.X.X.X --duration 24h --reason "Manual ban"

# Check bans
sudo cscli decisions list --limit 20

# Remove a ban
sudo cscli decisions delete --ip X.X.X.X
```

## Monitoring

```bash
# Check classifier logs
tail -f /var/log/smart-bans.log

# Check classified IPs
cat /var/lib/smart-ip-classifier/classified-ips.json | jq .

# Check violation counts
cat /var/lib/smart-ip-classifier/ip-violations.json | jq .
```

## Resource Usage

- **ip-api.com:** ~1 req/sec (well within 45/min limit)
- **CrowdSec:** ~100MB RAM, minimal CPU
- **Total:** < 1% CPU, < 50MB additional RAM
