# Firewall Service Restriction Guide

Restrict service access to specific network interfaces using iptables.

## Network Interfaces

Identify your interfaces:

```bash
ip addr show | grep -E "inet |^[0-9]+:"
```

Typical layout:

| Interface | Purpose |
|-----------|---------|
| `eth0` | LAN (physical network) |
| `tailscale0` | Tailscale VPN |
| `wg0` | WireGuard VPN |
| `docker0` | Docker bridge |

## Service Restrictions

### SMB (Ports 139/445)

**Risk:** EternalBlue, WannaCry, ransomware

```bash
# Allow from LAN, Tailscale, WireGuard
sudo iptables -I INPUT -p tcp -m multiport --dports 139,445 -s LAN_SUBNET -j ACCEPT
sudo iptables -I INPUT -p tcp -m multiport --dports 139,445 -s TAILSCALE_IP -j ACCEPT
sudo iptables -I INPUT -p tcp -m multiport --dports 139,445 -s WG_SUBNET -j ACCEPT

# Block all other
sudo iptables -A INPUT -p tcp -m multiport --dports 139,445 -j DROP
```

### CUPS (Port 631)

**Risk:** CVE-2024-47176, remote code execution

```bash
# Allow from LAN and Tailscale
sudo iptables -I INPUT -p tcp --dport 631 -s LAN_SUBNET -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 631 -s TAILSCALE_IP -j ACCEPT

# Block all other
sudo iptables -A INPUT -p tcp --dport 631 -j DROP
```

### MQTT (Ports 1883/9001)

**Risk:** Unauthorized IoT access

```bash
# Allow from LAN, Tailscale, Docker
sudo iptables -I INPUT -p tcp -m multiport --dports 1883,9001 -s LAN_SUBNET -j ACCEPT
sudo iptables -I INPUT -p tcp -m multiport --dports 1883,9001 -s TAILSCALE_IP -j ACCEPT
sudo iptables -I INPUT -p tcp -m multiport --dports 1883,9001 -s 172.17.0.0/16 -j ACCEPT

# Block all other
sudo iptables -A INPUT -p tcp -m multiport --dports 1883,9001 -j DROP
```

### FlareSolverr (Port 8191)

**Risk:** SSRF, Cloudflare bypass

```bash
# Allow from LAN, Tailscale, Docker
sudo iptables -I INPUT -p tcp --dport 8191 -s LAN_SUBNET -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 8191 -s TAILSCALE_IP -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 8191 -s 172.17.0.0/16 -j ACCEPT

# Block all other
sudo iptables -A INPUT -p tcp --dport 8191 -j DROP
```

### Duplicati (Port 8200) — Localhost Only

**Risk:** Backup data exposure

```bash
# Allow localhost only
sudo iptables -I INPUT -p tcp --dport 8200 -s 127.0.0.0/8 -j ACCEPT

# Block all other
sudo iptables -A INPUT -p tcp --dport 8200 -j DROP
```

**Note:** Google Drive backup is outbound — localhost-only binding doesn't break it.

## Docker-Specific Restrictions

For Docker containers, add rules in `DOCKER-USER` chain:

```bash
# Block external access to Duplicati
sudo iptables -I DOCKER-USER 1 -s 127.0.0.0/8 -p tcp --dport 8200 -j RETURN
sudo iptables -I DOCKER-USER 2 -p tcp --dport 8200 -j DROP
```

## Persisting Rules

```bash
# Save rules
sudo iptables-save > /etc/iptables/rules.v4

# Install persistence package
sudo apt-get install iptables-persistent
sudo netfilter-persistent save
```

## Verification

```bash
# Test from LAN (should work)
nc -z -w2 LAN_IP 445 && echo "SMB: OPEN" || echo "SMB: BLOCKED"

# Test from localhost (should work for localhost-only)
nc -z -w2 127.0.0.1 8200 && echo "Duplicati: OPEN" || echo "Duplicati: BLOCKED"
```
