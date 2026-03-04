#!/bin/sh
set -e

# Decode base64 credentials if provided (for Fly.io deployment)
if [ -n "$KIRO_CREDS_FILE_CONTENT" ]; then
  echo "Decoding Kiro credentials from KIRO_CREDS_FILE_CONTENT..."
  echo "$KIRO_CREDS_FILE_CONTENT" | base64 -d > /home/kiro/.aws/sso/cache/kiro-auth-token.json
  export KIRO_CREDS_FILE="/home/kiro/.aws/sso/cache/kiro-auth-token.json"
  echo "Credentials decoded successfully"
fi

# Start the application
exec python main.py
