# Fly.io Deployment - Quick Start Guide

Deploy Kiro Gateway to Fly.io in 5 minutes using AWS JSON file authentication.

## Prerequisites

- Fly.io account (sign up at https://fly.io)
- Fly CLI installed
- Kiro credentials file: `~/.aws/sso/cache/kiro-auth-token.json`

## Step-by-Step Deployment

### 1. Install Fly CLI

```bash
# macOS
brew install flyctl

# Linux
curl -L https://fly.io/install.sh | sh

# Windows (PowerShell)
powershell -Command "iwr https://fly.io/install.ps1 -useb | iex"

# Login
fly auth login
```

### 2. Encode Your Credentials

```bash
# macOS/Linux
cat ~/.aws/sso/cache/kiro-auth-token.json | base64 -w 0

# Windows (PowerShell)
[Convert]::ToBase64String([System.IO.File]::ReadAllBytes("$env:USERPROFILE\.aws\sso\cache\kiro-auth-token.json"))
```

**Save the output** - you'll need it in step 4.

### 3. Launch App

```bash
cd kiro-gateway

# Create app (don't deploy yet)
fly launch --no-deploy

# Choose:
# - App name (or auto-generate)
# - Region (sin=Singapore, iad=US East, lhr=London)
# - No database needed
```

### 4. Set Secrets

```bash
# Your gateway password (make it strong!)
fly secrets set PROXY_API_KEY="your-super-secret-password-123"

# Your Kiro credentials (paste base64 from step 2)
fly secrets set KIRO_CREDS_FILE_CONTENT="<paste-base64-here>"
```

### 5. Deploy

```bash
fly deploy
```

That's it! Your gateway is live at `https://your-app-name.fly.dev`

## Test Your Deployment

```bash
# Check health
curl https://your-app-name.fly.dev/health

# Test chat completion
curl https://your-app-name.fly.dev/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-super-secret-password-123" \
  -d '{
    "model": "claude-sonnet-4.5",
    "messages": [{"role": "user", "content": "Say hello!"}]
  }'
```

## Common Commands

```bash
# View logs
fly logs

# Check status
fly status

# Scale memory (if needed)
fly scale memory 512

# Update secrets
fly secrets set PROXY_API_KEY="new-password"

# Redeploy after code changes
git pull
fly deploy

# Destroy app
fly apps destroy kiro-gateway
```

## Configuration

Edit `fly.toml` to customize:

- **Region**: Change `primary_region = "sin"` to your preferred region
- **Memory**: Change `memory_mb = 256` (increase if needed)
- **Auto-scaling**: Already configured to scale to zero when idle

## Troubleshooting

**Deployment fails?**
```bash
fly logs
fly deploy --force
```

**Authentication errors?**
```bash
# Verify credentials
fly ssh console
cat /home/kiro/.aws/sso/cache/kiro-auth-token.json

# Update credentials
fly secrets set KIRO_CREDS_FILE_CONTENT="<new-base64>"
```

**Out of memory?**
```bash
fly scale memory 512
```

## Cost

Fly.io free tier includes:
- 3 shared VMs with 256MB RAM
- Auto-stop when idle (no charges)
- Auto-start on request

Your gateway will cost **$0/month** if you stay within free tier limits.

## Next Steps

- [Full deployment guide](fly-deployment.md) - Advanced configuration
- [Custom domain setup](https://fly.io/docs/networking/custom-domain/)
- [Monitoring and metrics](https://fly.io/docs/metrics-and-logs/)

## Support

- Kiro Gateway: https://github.com/jwadow/kiro-gateway/issues
- Fly.io Docs: https://fly.io/docs/
- Fly.io Community: https://community.fly.io/
