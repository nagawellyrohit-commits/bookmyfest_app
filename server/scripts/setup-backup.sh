#!/bin/bash

# Exit on any error
set -e

# Resolve script path to allow execution from any directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

# Load environment variables
if [ -f "$ENV_FILE" ]; then
  # Read .env while skipping comments and empty lines
  export $(grep -v '^#' "$ENV_FILE" | xargs)
else
  echo "❌ Error: .env file not found at $ENV_FILE"
  exit 1
fi

# Ensure required env variables are present
if [ -z "$BACKUP_BASE_DIR" ] || [ -z "$RESTIC_PASSWORD_FILE" ]; then
  echo "❌ Error: BACKUP_BASE_DIR and RESTIC_PASSWORD_FILE must be configured in .env"
  exit 1
fi

echo "⚙️ Setting up BookMyFest Restic Backup System..."

# 1. Create target directories
echo "Creating backup runtime directories under $BACKUP_BASE_DIR..."
mkdir -p "$BACKUP_BASE_DIR/repository"
mkdir -p "$BACKUP_BASE_DIR/tmp"
mkdir -p "$BACKUP_BASE_DIR/logs"

# 2. Configure password file
if [ ! -f "$RESTIC_PASSWORD_FILE" ]; then
  echo "Generating secure password at $RESTIC_PASSWORD_FILE..."
  if ! command -v openssl &> /dev/null; then
    echo "❌ Error: OpenSSL is not installed. OpenSSL is required to generate a cryptographically strong Restic password."
    exit 1
  fi
  openssl rand -base64 32 > "$RESTIC_PASSWORD_FILE"
  chmod 600 "$RESTIC_PASSWORD_FILE"
  echo "🔒 Password file generated successfully with secure permissions (chmod 600)."
else
  echo "🔒 Password file already exists at $RESTIC_PASSWORD_FILE."
  chmod 600 "$RESTIC_PASSWORD_FILE" || true
fi

# 3. Check if Restic is installed
if ! command -v restic &> /dev/null; then
  echo "⚠️ Warning: 'restic' is not installed or not in PATH."
  echo "👉 Please install it using: sudo apt install restic (Ubuntu/Debian) or brew install restic (macOS)"
  exit 0
fi

# 4. Initialize Restic Repository
if [ ! -f "$BACKUP_BASE_DIR/repository/config" ]; then
  echo "Initializing Restic repository..."
  restic -r "$BACKUP_BASE_DIR/repository" --password-file "$RESTIC_PASSWORD_FILE" init
  echo "✅ Restic repository initialized successfully at $BACKUP_BASE_DIR/repository!"
else
  echo "✅ Restic repository already initialized at $BACKUP_BASE_DIR/repository."
fi

echo "🚀 Setup completed successfully!"
