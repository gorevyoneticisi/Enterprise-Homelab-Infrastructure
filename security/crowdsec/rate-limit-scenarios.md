# CrowdSec Rate-Limiting Scenarios

Custom CrowdSec scenarios for rate-limit based banning.

## Overview

CrowdSec detects attacks by analyzing logs and matching patterns against scenarios. Rate-limiting scenarios track request frequency per IP and ban when thresholds are exceeded.

## Custom Scenarios

### 1. General Rate Limit (10+ requests in 60 seconds)

File: `/etc/crowdsec/scenarios/custom-rate-limit.yaml`

```yaml
type: leaky
name: custom/rate-limit-60s
description: "Detect IPs making 10+ requests in 60 seconds"
filter: "evt.Meta.log_type == 'http_access_log'"
leakspeed: 6s
capacity: 9
groupby: "evt.Meta.source_ip"
blackhole: 5m
labels:
  confidence: 1
  spoofable: 0
  classification:
    - attack.T1595
  behavior: "http:rate-limit"
  service: http
  label: "Rate Limit Exceeded"
  remediation: true
```

**How it works:**
- Leaky bucket algorithm (memory-efficient)
- Bucket holds 9 events, leaks 1 every 6 seconds
- After 60 seconds with 10+ requests → ban
- Blackhole prevents duplicate alerts for 5 minutes

### 2. Aggressive Scanner (5+ requests in 30 seconds)

File: `/etc/crowdsec/scenarios/custom-aggressive-scanner.yaml`

```yaml
type: leaky
name: custom/aggressive-scanner
description: "Detect aggressive scanners - 5+ requests in 30 seconds"
filter: "evt.Meta.log_type == 'http_access_log'"
leakspeed: 6s
capacity: 4
groupby: "evt.Meta.source_ip"
blackhole: 5m
labels:
  confidence: 1
  spoofable: 0
  classification:
    - attack.T1595
  behavior: "http:scanner"
  service: http
  label: "Aggressive Scanner"
  remediation: true
```

**How it works:**
- Stricter threshold for fast scanners
- Catches path enumeration attacks
- 5 requests in 30 seconds → ban

## Installation

```bash
# Copy scenarios
sudo cp custom-rate-limit.yaml /etc/crowdsec/scenarios/
sudo cp custom-aggressive-scanner.yaml /etc/crowdsec/scenarios/

# Restart CrowdSec
sudo systemctl restart crowdsec

# Verify
sudo cscli scenarios list | grep custom
```

## Tuning

Adjust thresholds based on your traffic:

| Traffic Level | Rate-Limit | Aggressive Scanner |
|---------------|------------|-------------------|
| Low (< 100 req/min) | 10 req/60s | 5 req/30s |
| Medium (100-1000) | 20 req/60s | 10 req/30s |
| High (> 1000) | 50 req/60s | 20 req/30s |

## Built-in Scenarios to Enable

```bash
# HTTP protection
sudo cscli scenarios enable crowdsecurity/http-crawl-non_statics
sudo cscli scenarios enable crowdsecurity/http-bad-user-agent
sudo cscli scenarios enable crowdsecurity/http-probing
sudo cscli scenarios enable crowdsecurity/http-sensitive-files

# SSH protection
sudo cscli scenarios enable crowdsecurity/ssh-bf
sudo cscli scenarios enable crowdsecurity/ssh-slow-bf
```

## Monitoring

```bash
# View alerts
sudo cscli alerts list --limit 20

# View bans
sudo cscli decisions list --limit 20

# View metrics
sudo cscli metrics
```
