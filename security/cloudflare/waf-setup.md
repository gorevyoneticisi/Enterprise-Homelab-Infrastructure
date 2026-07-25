# Cloudflare WAF Setup Guide

WAF rules to protect services behind Cloudflare proxy.

## WAF Custom Rules

Go to **Security** → **WAF** → **Custom rules** → **Create rule**

### Rule 1: Block Environment File Probes

```
Rule name: Block .env probes
When: http.request.uri.path contains "/.env"
Action: Block
```

**Why:** Attackers scan for `.env` files to steal secrets and API keys.

### Rule 2: Block Git Directory Probes

```
Rule name: Block .git probes
When: http.request.uri.path contains "/.git"
Action: Block
```

**Why:** `.git/config` exposure reveals repository URLs and sometimes credentials.

### Rule 3: Block PHP Paths (Non-PHP Apps)

```
Rule name: Block PHP paths
When: http.request.uri.path contains ".php"
Action: Block
```

**Why:** If your app is Node.js/Python, no PHP should be served.

### Rule 4: Block WordPress Paths (Non-WordPress Apps)

```
Rule name: Block WP paths
When: http.request.uri.path contains "/wp-" or http.request.uri.path contains "/xmlrpc"
Action: Block
```

**Why:** WordPress brute force and XML-RPC amplification attacks.

### Rule 5: Block Exploit Scanner Paths

```
Rule name: Block exploit scanners
When: http.request.uri.path contains "/vendor/phpunit" or http.request.uri.path contains "/laravel" or http.request.uri.path contains "/alfacgiapi"
Action: Block
```

**Why:** Known PHP framework exploit paths.

### Rule 6: Block GraphQL Probing

```
Rule name: Block GraphQL probes
When: http.request.uri.path contains "/graphql" or http.request.uri.path contains "/api/gql"
Action: Block
```

**Why:** GraphQL introspection attacks.

### Rule 7: Block Sensitive Files

```
Rule name: Block sensitive files
When: http.request.uri.path contains "/.htaccess" or http.request.uri.path contains "/config.json" or http.request.uri.path contains "/phpinfo"
Action: Block
```

**Why:** Config files and PHP info disclosure.

## Bot Fight Mode

Go to **Security** → **Bots** → **Bot Fight Mode**

- Toggle **ON**
- **Definitely automated** → Block
- **Likely automated** → Managed Challenge

## Testing

```bash
# Should return 200
curl -s -o /dev/null -w "%{http_code}" -A "Mozilla/5.0" https://yourdomain.com/

# Should return 403 (blocked)
curl -s -o /dev/null -w "%{http_code}" https://yourdomain.com/.env
curl -s -o /dev/null -w "%{http_code}" https://yourdomain.com/.git/config
curl -s -o /dev/null -w "%{http_code}" https://yourdomain.com/wp-login.php
```

## Free Tier Limits

- 5 WAF Custom Rules
- No Rate Limiting Rules (paid)
- Bot Fight Mode available
