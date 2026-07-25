#!/bin/bash
# Smart IP Blocking Setup Script
# Sets up CrowdSec rate-limiting, IP classification, and automated banning
#
# Usage: sudo bash setup-smart-blocking.sh
#
# Requirements:
# - CrowdSec installed and running
# - iptables installed
# - curl and jq installed
# - Root access

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[-]${NC} $1"; exit 1; }

check_requirements() {
    log "Checking requirements..."
    command -v curl >/dev/null 2>&1 || error "curl not found"
    command -v jq >/dev/null 2>&1 || error "jq not found"
    command -v cscli >/dev/null 2>&1 || error "CrowdSec not found"
    systemctl is-active --quiet crowdsec || error "CrowdSec not running"
    log "Requirements met"
}

setup_crowdsec_scenarios() {
    log "Setting up CrowdSec rate-limit scenarios..."
    
    cat > /etc/crowdsec/scenarios/custom-rate-limit.yaml << 'EOF'
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
EOF
    
    cat > /etc/crowdsec/scenarios/custom-aggressive-scanner.yaml << 'EOF'
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
EOF
    
    log "CrowdSec scenarios created"
}

create_classifier_script() {
    log "Creating smart IP classifier..."
    
    cat > /usr/local/bin/smart-ip-classifier.sh << 'SCRIPT'
#!/bin/bash
LOG="/var/log/smart-bans.log"
CLASSIFIED="/var/lib/smart-ip-classifier/classified-ips.json"
VIOLATIONS="/var/lib/smart-ip-classifier/ip-violations.json"

mkdir -p /var/lib/smart-ip-classifier
[ -f "$CLASSIFIED" ] || echo '{}' > "$CLASSIFIED"
[ -f "$VIOLATIONS" ] || echo '{}' > "$VIOLATIONS"

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Smart classifier running" >> "$LOG"

ALERTS=$(cscli alerts list --limit 100 --format json 2>/dev/null | jq -r '.[].source_ip' 2>/dev/null | sort -u)

for ip in $ALERTS; do
    if echo "$ip" | grep -qE "^(127\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|169\.254\.)"; then
        continue
    fi
    
    EXISTING=$(jq -r ".[\"$ip\"]" "$CLASSIFIED" 2>/dev/null)
    if [ "$EXISTING" != "null" ] && [ -n "$EXISTING" ]; then
        CLASS=$(jq -r ".[\"$ip\"].class" "$CLASSIFIED" 2>/dev/null)
        VIOLATION_COUNT=$(jq -r ".[\"$ip\"].violations // 0" "$VIOLATIONS" 2>/dev/null)
        VIOLATION_COUNT=$((VIOLATION_COUNT + 1))
        jq ".[\"$ip\"].violations = $VIOLATION_COUNT" "$VIOLATIONS" > /tmp/v-tmp && mv /tmp/v-tmp "$VIOLATIONS"
        
        case "$CLASS" in
            datacenter)
                if [ "$VIOLATION_COUNT" -ge 5 ]; then
                    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] BANNED datacenter: $ip" >> "$LOG"
                    iptables -I INPUT -s "$ip" -j DROP
                    cscli decisions add --ip "$ip" --duration 24h --reason "Datacenter IP" 2>/dev/null
                fi
                ;;
            proxy|vpn)
                if [ "$VIOLATION_COUNT" -ge 3 ]; then
                    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] BANNED proxy: $ip" >> "$LOG"
                    iptables -I INPUT -s "$ip" -j DROP
                    cscli decisions add --ip "$ip" --duration 24h --reason "Proxy IP" 2>/dev/null
                fi
                ;;
            residential)
                if [ "$VIOLATION_COUNT" -ge 10 ]; then
                    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] BANNED residential: $ip" >> "$LOG"
                    iptables -I INPUT -s "$ip" -j DROP
                    cscli decisions add --ip "$ip" --duration 1h --reason "Residential IP" 2>/dev/null
                fi
                ;;
        esac
        continue
    fi
    
    GEO=$(curl -s --max-time 5 "http://ip-api.com/json/$ip?fields=status,isp,org,hosting,proxy" 2>/dev/null)
    STATUS=$(echo "$GEO" | jq -r '.status' 2>/dev/null)
    
    if [ "$STATUS" = "success" ]; then
        HOSTING=$(echo "$GEO" | jq -r '.hosting' 2>/dev/null)
        PROXY=$(echo "$GEO" | jq -r '.proxy' 2>/dev/null)
        ORG=$(echo "$GEO" | jq -r '.org' 2>/dev/null)
        
        if [ "$HOSTING" = "true" ] || [ "$PROXY" = "true" ]; then
            CLASS=$( [ "$PROXY" = "true" ] && echo "proxy" || echo "datacenter" )
        else
            CLASS="residential"
        fi
        
        jq ".[\"$ip\"] = {\"class\": \"$CLASS\", \"org\": \"$ORG\"}" "$CLASSIFIED" > /tmp/c-tmp && mv /tmp/c-tmp "$CLASSIFIED"
        jq ".[\"$ip\"] = {\"violations\": 1}" "$VIOLATIONS" > /tmp/v-tmp && mv /tmp/v-tmp "$VIOLATIONS"
        
        if [ "$CLASS" = "datacenter" ]; then
            if echo "$ORG" | grep -qiE "microsoft|amazon|google|oracle|digitalocean|linode|vultr|hetzner|ovh"; then
                echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] AUTO-BANNED datacenter: $ip ($ORG)" >> "$LOG"
                iptables -I INPUT -s "$ip" -j DROP
                cscli decisions add --ip "$ip" --duration 24h --reason "Auto-banned: $ORG" 2>/dev/null
            fi
        fi
        
        if [ "$CLASS" = "proxy" ]; then
            echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] AUTO-BANNED proxy: $ip ($ORG)" >> "$LOG"
            iptables -I INPUT -s "$ip" -j DROP
            cscli decisions add --ip "$ip" --duration 24h --reason "Auto-banned proxy: $ORG" 2>/dev/null
        fi
    fi
    
    sleep 1
done

iptables-save > /etc/iptables/rules.v4 2>/dev/null
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Smart classifier complete" >> "$LOG"
SCRIPT
    
    chmod +x /usr/local/bin/smart-ip-classifier.sh
    log "Smart IP classifier created"
}

create_ai_scraper_blocker() {
    log "Creating AI scraper blocker..."
    
    cat > /usr/local/bin/block-ai-scrapers.sh << 'SCRIPT'
#!/bin/bash
LOG="/var/log/ai-scraper-bans.log"
AI_BOTS="GPTBot|ChatGPT-User|CCBot|Bytespider|Google-Extended|anthropic-ai|ClaudeBot|FacebookBot|meta-externalagent|PerplexityBot"

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Running AI scraper check" >> "$LOG"

docker logs nginx-proxy-manager --since 6h 2>/dev/null | \
  grep -iE "$AI_BOTS" | \
  grep -oP '\[Client \K[0-9a-f.:]+' | \
  sort -u | while read ip; do
    if iptables -C INPUT -s "$ip" -j DROP 2>/dev/null; then
      continue
    fi
    
    GEO=$(curl -s --max-time 5 "http://ip-api.com/json/$ip?fields=status,org,hosting" 2>/dev/null)
    HOSTING=$(echo "$GEO" | jq -r '.hosting' 2>/dev/null)
    ORG=$(echo "$GEO" | jq -r '.org' 2>/dev/null)
    
    if [ "$HOSTING" = "true" ]; then
      echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] BANNED AI scraper: $ip ($ORG)" >> "$LOG"
      iptables -I INPUT -s "$ip" -j DROP
      cscli decisions add --ip "$ip" --duration 168h --reason "AI scraper: $ORG" 2>/dev/null
    fi
done

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] AI scraper check complete" >> "$LOG"
SCRIPT
    
    chmod +x /usr/local/bin/block-ai-scrapers.sh
    log "AI scraper blocker created"
}

install_cron_jobs() {
    log "Installing cron jobs..."
    (crontab -l 2>/dev/null; echo "# Smart IP blocking"; echo "*/30 * * * * /usr/local/bin/smart-ip-classifier.sh"; echo "0 */6 * * * /usr/local/bin/block-ai-scrapers.sh") | sort -u | crontab -
    log "Cron jobs installed"
}

restart_crowdsec() {
    log "Restarting CrowdSec..."
    systemctl restart crowdsec
    sleep 3
    systemctl is-active --quiet crowdsec && log "CrowdSec restarted" || error "CrowdSec failed to start"
}

main() {
    echo "=========================================="
    echo "  Smart IP Blocking Setup"
    echo "=========================================="
    echo ""
    
    check_requirements
    setup_crowdsec_scenarios
    create_classifier_script
    create_ai_scraper_blocker
    install_cron_jobs
    restart_crowdsec
    
    echo ""
    echo "=========================================="
    echo "  Setup Complete!"
    echo "=========================================="
    echo ""
    echo "Installed:"
    echo "  - CrowdSec rate-limit scenarios"
    echo "  - Smart IP classifier (every 30 min)"
    echo "  - AI scraper blocker (every 6 hours)"
    echo ""
    echo "Ban thresholds:"
    echo "  - Datacenter: 24h after 5 violations"
    echo "  - Proxy/VPN: 24h after 3 violations"
    echo "  - Residential: 1h after 10 violations"
}

main "$@"
