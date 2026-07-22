#!/bin/bash

# Resolve directory paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

# Load environment variables
if [ -f "$ENV_FILE" ]; then
  export $(grep -v '^#' "$ENV_FILE" | xargs)
else
  echo "❌ Error: .env file not found at $ENV_FILE"
  exit 1
fi

# Ensure required variables are present
if [ -z "$BACKUP_BASE_DIR" ] || [ -z "$RESTIC_PASSWORD_FILE" ]; then
  echo "❌ Error: BACKUP_BASE_DIR and RESTIC_PASSWORD_FILE must be configured in .env"
  exit 1
fi

# Setup monthly log file
LOG_YEAR_MONTH=$(date +"%Y-%m")
LOG_FILE="$BACKUP_BASE_DIR/logs/verify-$LOG_YEAR_MONTH.log"
mkdir -p "$BACKUP_BASE_DIR/logs"

# Helper for logging
log_message() {
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

export RESTIC_PASSWORD_FILE
export RESTIC_REPOSITORY="$BACKUP_BASE_DIR/repository"

# Check if Restic is installed
if ! command -v restic &> /dev/null; then
  echo "❌ Error: 'restic' is not installed or not in PATH."
  exit 1
fi

log_message "🔍 Starting BookMyFest Restic Backup Verification..."

if [ "$1" = "--full" ]; then
  log_message "Running full cryptographic read-data verification (this will check all stored blocks)..."
  VERIFY_OUTPUT=$(restic check --read-data 2>&1)
  STATUS=$?
else
  log_message "Running standard repository structure checks..."
  VERIFY_OUTPUT=$(restic check 2>&1)
  STATUS=$?
fi

if [ $STATUS -eq 0 ]; then
  log_message "✅ Verification SUCCESS. Restic repository is healthy and consistent."
  log_message "Check output:\n$VERIFY_OUTPUT"
else
  log_message "❌ Verification FAILED. Possible data corruption detected."
  log_message "Error output:\n$VERIFY_OUTPUT"
  
  # Send alert notification
  node "$SCRIPT_DIR/notify.js" "FAILED" "Restic repository verification check failed!\n\n$VERIFY_OUTPUT"
  exit 1
fi

exit 0
