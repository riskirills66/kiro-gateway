# Deploying Kiro Gateway to Fly.io

This guide shows you how to deploy Kiro Gateway to Fly.io using AWS JSON file authentication (no database needed).

## Prerequisites

1. **Fly.io account** - Sign up at https://fly.io
2. **Fly CLI** - Install from https://fly.io/docs/hands-on/install-flyctl/
3. **Kiro credentials** - AWS JSON file from Kiro IDE (`~/.aws/sso/cache/kiro-auth-token.json`)

## Quick Start

### 1. Install Fly CLI

```bash
# macOS
brew install flyctl

# Linux
curl -L https://fly.io/install.sh | sh

# Windows
powershell -Command "iwr https://fly.io/install.ps1 -useb | iex"

# Login to Fly.io
fly auth login
```

### 2. Prepare Your Credentials

You need to encode your AWS JSON credentials file to base64:

```bash
# macOS/Linux
cat ~/.aws/sso/cache/kiro-auth-token.json | base64 -w 0

# Windows (PowerShell)
[Convert]::ToBase64String([System.IO.File]::ReadAllBytes("$env:USERPROFILE\.aws\sso\cache\kiro-auth-token.json"))
```

Copy the output - you'll need it in the next step.

### 3. Create Fly.io App

```bash
# Navigate to your kiro-gateway directory
cd kiro-gateway

# Create a new Fly.io app (this uses the fly.toml config)
fly launch --no-deploy

# Follow the prompts:
# - Choose app name (or use auto-generated)
# - Choose region (e.g., sin for Singapore, iad for US East)
# - Don't add PostgreSQL or Redis
```

### 4. Set Secrets

Set your secrets (these are encrypted and never exposed):

```bash
# Required: Your gateway password (make up a strong password)
fly secrets set PROXY_API_KEY="your-super-secret-password-123"

# Required: Your Kiro credentials (paste the base64 string from step 2)
fly secrets set KIRO_CREDS_FILE_CONTENT="<paste-base64-here>"

# Optional: Profile ARN (usually auto-detected from credentials)
# fly secrets set PROFILE_ARN="arn:aws:codewhisperer:us-east-1:..."

# Optional: VPN/Proxy if needed
# fly secrets set VPN_PROXY_URL="http://127.0.0.1:7890"
```

### 5. Update Dockerfile for Fly.io

The gateway needs a small modification to handle the base64 credentials. Add this to the Dockerfile:

```dockerfile
# Add after USER kiro line
# Decode credentials from environment variable at runtime
RUN echo '#!/bin/sh\n\
if [ -n "$KIRO_CREDS_FILE_CONTENT" ]; then\n\
  mkdir -p /home/kiro/.aws/sso/cache\n\
  echo "$KIRO_CREDS_FILE_CONTENT" | base64 -d > /home/kiro/.aws/sso/cache/kiro-auth-token.json\n\
  export KIRO_CREDS_FILE="/home/kiro/.aws/sso/cache/kiro-auth-token.json"\n\
fi\n\
exec python main.py' > /app/entrypoint.sh && chmod +x /app/entrypoint.sh

CMD ["/app/entrypoint.sh"]
```

### 6. Deploy

```bash
# Deploy to Fly.io
fly deploy

# Check status
fly status

# View logs
fly logs

# Open in browser
fly open
```

## Configuration

### fly.toml Settings

The `fly.toml` file contains your app configuration:

```toml
app = "kiro-gateway"
primary_region = "sin"  # Change to your preferred region

[http_service]
  internal_port = 8000
  force_https = true
  auto_stop_machines = true      # Stop when idle
  auto_start_machines = true     # Start on request
  min_machines_running = 0       # Scale to zero when idle

[env]
  SERVER_HOST = "0.0.0.0"
  SERVER_PORT = "8000"
  KIRO_REGION = "us-east-1"
  LOG_LEVEL = "INFO"
  DEBUG_MODE = "off"
  FAKE_REASONING = "true"
  TRUNCATION_RECOVERY = "true"

[[vm]]
  cpu_kind = "shared"
  cpus = 1
  memory_mb = 256  # Increase if needed
```

### Available Regions

Choose a region close to you for better latency:

- `sin` - Singapore
- `nrt` - Tokyo, Japan
- `hkg` - Hong Kong
- `syd` - Sydney, Australia
- `iad` - Ashburn, Virginia (US)
- `lax` - Los Angeles, California (US)
- `lhr` - London, UK
- `fra` - Frankfurt, Germany

Full list: https://fly.io/docs/reference/regions/

### Scaling

```bash
# Scale to 512MB RAM (if 256MB is not enough)
fly scale memory 512

# Scale to 2 CPUs
fly scale vm shared-cpu-2x

# Set minimum running machines
fly scale count 1  # Always keep 1 running

# Scale to zero (save costs)
fly scale count 0 --max-per-region 1
```

## Usage

Once deployed, your gateway will be available at:

```
https://your-app-name.fly.dev
```

### Connect from OpenAI-compatible clients

```bash
# Example with curl
curl https://your-app-name.fly.dev/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-super-secret-password-123" \
  -d '{
    "model": "claude-sonnet-4.5",
    "messages": [{"role": "user", "content": "Hello!"}],
    "stream": true
  }'
```

### Connect from Anthropic-compatible clients

```bash
curl https://your-app-name.fly.dev/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: your-super-secret-password-123" \
  -H "anthropic-version: 2023-06-01" \
  -d '{
    "model": "claude-sonnet-4.5",
    "max_tokens": 1024,
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## Monitoring

```bash
# View logs (live)
fly logs

# View app status
fly status

# View metrics
fly dashboard

# SSH into the machine
fly ssh console

# Check health
curl https://your-app-name.fly.dev/health
```

## Troubleshooting

### Deployment fails

```bash
# Check logs
fly logs

# Verify secrets are set
fly secrets list

# Redeploy
fly deploy --force
```

### Authentication errors

```bash
# Verify credentials are valid
fly ssh console
cat /home/kiro/.aws/sso/cache/kiro-auth-token.json

# Update credentials
fly secrets set KIRO_CREDS_FILE_CONTENT="<new-base64>"
fly deploy
```

### Out of memory

```bash
# Scale up memory
fly scale memory 512

# Or use a larger VM
fly scale vm shared-cpu-2x
```

### Slow responses

```bash
# Check region latency
fly status

# Move to closer region
fly regions set sin  # Example: Singapore

# Add more regions for redundancy
fly regions add nrt hkg
```

## Cost Optimization

Fly.io offers generous free tier:

- **Free allowance**: 3 shared-cpu-1x VMs with 256MB RAM
- **Auto-stop**: Machines stop when idle (no charges)
- **Auto-start**: Machines start on first request (~1-2s cold start)

Tips to minimize costs:

1. Use `auto_stop_machines = true` (default in fly.toml)
2. Use `min_machines_running = 0` to scale to zero
3. Use 256MB RAM (sufficient for most use cases)
4. Deploy in single region (add more only if needed)

## Security

### Best Practices

1. **Use strong PROXY_API_KEY** - This protects your gateway
2. **Enable HTTPS** - Already configured in fly.toml
3. **Rotate credentials** - Update secrets periodically
4. **Monitor logs** - Check for suspicious activity
5. **Limit access** - Use Fly.io's private networking if needed

### Private Networking (Optional)

To restrict access to your Fly.io network only:

```bash
# Remove public HTTP service
fly scale count 0

# Use Fly.io private networking
# Connect via WireGuard VPN or Fly Proxy
```

## Updating

```bash
# Pull latest changes
git pull

# Redeploy
fly deploy

# Or force rebuild
fly deploy --force
```

## Cleanup

```bash
# Destroy the app (careful!)
fly apps destroy kiro-gateway

# Or just stop it
fly scale count 0
```

## Support

- **Fly.io Docs**: https://fly.io/docs/
- **Kiro Gateway Issues**: https://github.com/jwadow/kiro-gateway/issues
- **Fly.io Community**: https://community.fly.io/

## Next Steps

- Set up custom domain: https://fly.io/docs/networking/custom-domain/
- Add monitoring: https://fly.io/docs/metrics-and-logs/
- Configure autoscaling: https://fly.io/docs/reference/autoscaling/
- Set up CI/CD: https://fly.io/docs/app-guides/continuous-deployment-with-github-actions/
