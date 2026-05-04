#!/bin/bash

# Configuration variables
IP_API="https://api.ipify.org"
WHITELIST_FILE="/etc/crowdsec/parsers/s02-enrich/dynamic_wan_whitelist.yaml"
STATE_FILE="/var/tmp/last_wan_ip.txt"

# Fetch current external IP
CURRENT_IP=$(curl -s -4 "$IP_API")

# Validate the output is a standard IPv4 address
if [[ ! $CURRENT_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Invalid IP retrieved from API."
    exit 1
fi

# Read the last known IP from the state file
if [ -f "$STATE_FILE" ]; then
    LAST_IP=$(cat "$STATE_FILE")
else
    LAST_IP=""
fi

# Compare current IP with the last known IP
if [ "$CURRENT_IP" != "$LAST_IP" ]; then
    
    # Generate the new YAML whitelist configuration
    cat <<EOF > "$WHITELIST_FILE"
name: crowdsecurity/dynamic_wan_whitelist
description: "Automated whitelist for dynamic WAN IP"
whitelist:
  reason: "Automated homelab dynamic IP whitelist"
  ip:
    - "$CURRENT_IP"
EOF
    
    # Reload CrowdSec to apply the parser changes
    systemctl reload crowdsec
    
    # Update the state file with the new IP
    echo "$CURRENT_IP" > "$STATE_FILE"
fi
