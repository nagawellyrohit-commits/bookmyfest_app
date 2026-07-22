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
LOG_FILE="$BACKUP_BASE_DIR/logs/restore-test-$LOG_YEAR_MONTH.log"
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
  log_message "❌ Error: 'restic' is not installed or not in PATH."
  exit 1
fi

log_message "🚀 Starting BookMyFest Automated Monthly Backup Restore Test..."

# Setup sandbox path
SANDBOX_DIR="$BACKUP_BASE_DIR/tmp/test_restore_sandbox"
rm -rf "$SANDBOX_DIR"
mkdir -p "$SANDBOX_DIR"

DETAILS_BUFFER=""
append_details() {
  DETAILS_BUFFER="$DETAILS_BUFFER$1\n"
  log_message "$1"
}

append_details "Restoring latest snapshot files into sandbox directory $SANDBOX_DIR..."

# Restore latest snapshot
if ! restic restore latest --target "$SANDBOX_DIR" &> "$BACKUP_BASE_DIR/tmp/test_restore_output.log"; then
  RESTORE_ERR=$(cat "$BACKUP_BASE_DIR/tmp/test_restore_output.log")
  append_details "❌ Restic restore command failed."
  append_details "Details:\n$RESTORE_ERR"
  rm -rf "$SANDBOX_DIR"
  rm -f "$BACKUP_BASE_DIR/tmp/test_restore_output.log"
  node "$SCRIPT_DIR/notify.js" "FAILED" "Monthly Restore Test Failed:\n\n$DETAILS_BUFFER"
  exit 1
fi

rm -f "$BACKUP_BASE_DIR/tmp/test_restore_output.log"
append_details "✅ Restic restore completed in sandbox."

# 1. Verify Restored Database Dump
RESTORED_DB_DUMP=$(find "$SANDBOX_DIR" -name "db_backup.sql.gz" | head -n 1)

if [ -z "$RESTORED_DB_DUMP" ] || [ ! -f "$RESTORED_DB_DUMP" ]; then
  append_details "❌ Validation failed: db_backup.sql.gz was not found in the restored snapshot."
  rm -rf "$SANDBOX_DIR"
  node "$SCRIPT_DIR/notify.js" "FAILED" "Monthly Restore Test Failed:\n\n$DETAILS_BUFFER"
  exit 1
fi

FILE_SIZE=$(wc -c <"$RESTORED_DB_DUMP" | tr -d ' ')
if [ "$FILE_SIZE" -eq 0 ]; then
  append_details "❌ Validation failed: Restored db_backup.sql.gz is empty (0 bytes)."
  rm -rf "$SANDBOX_DIR"
  node "$SCRIPT_DIR/notify.js" "FAILED" "Monthly Restore Test Failed:\n\n$DETAILS_BUFFER"
  exit 1
fi

if ! gzip -t "$RESTORED_DB_DUMP"; then
  append_details "❌ Validation failed: Restored db_backup.sql.gz failed gzip integrity test."
  rm -rf "$SANDBOX_DIR"
  node "$SCRIPT_DIR/notify.js" "FAILED" "Monthly Restore Test Failed:\n\n$DETAILS_BUFFER"
  exit 1
fi

append_details "✅ Restored database dump verified successfully (Size: $FILE_SIZE bytes)."

# 1.5 Verify Restored Metadata JSON
RESTORED_METADATA=$(find "$SANDBOX_DIR" -name "metadata.json" | head -n 1)

if [ -z "$RESTORED_METADATA" ] || [ ! -f "$RESTORED_METADATA" ]; then
  append_details "❌ Validation failed: metadata.json was not found in the restored snapshot."
  rm -rf "$SANDBOX_DIR"
  node "$SCRIPT_DIR/notify.js" "FAILED" "Monthly Restore Test Failed:\n\n$DETAILS_BUFFER"
  exit 1
fi

METADATA_CONTENT=$(cat "$RESTORED_METADATA" || echo "")
IS_BOOKMYFEST=$(node -e "
try {
  const meta = JSON.parse(process.argv[2]);
  console.log(meta.application === 'BookMyFest');
} catch (e) {
  console.log('false');
}
" "$METADATA_CONTENT" 2>/dev/null || echo "false")

if [ "$IS_BOOKMYFEST" != "true" ]; then
  append_details "❌ Validation failed: Restored metadata.json is invalid or has wrong app name."
  append_details "Content: $METADATA_CONTENT"
  rm -rf "$SANDBOX_DIR"
  node "$SCRIPT_DIR/notify.js" "FAILED" "Monthly Restore Test Failed:\n\n$DETAILS_BUFFER"
  exit 1
fi

append_details "✅ Restored backup metadata verified successfully: $METADATA_CONTENT"

# 2. Verify Restored Storage Root
RESTORED_STORAGE_ROOT=$(find "$SANDBOX_DIR" -path "*/var/www/bookmyfest_storage" | head -n 1)

if [ -z "$RESTORED_STORAGE_ROOT" ] || [ ! -d "$RESTORED_STORAGE_ROOT" ]; then
  append_details "❌ Validation failed: bookmyfest_storage directory was not found in the restored snapshot."
  rm -rf "$SANDBOX_DIR"
  node "$SCRIPT_DIR/notify.js" "FAILED" "Monthly Restore Test Failed:\n\n$DETAILS_BUFFER"
  exit 1
fi

append_details "✅ Restored storage root verified successfully."

# Clean up sandbox
rm -rf "$SANDBOX_DIR"
append_details "✅ Sandbox test directory cleaned up."

log_message "🎉 Monthly restore test completed successfully! Backups are verified as functional."
node "$SCRIPT_DIR/notify.js" "SUCCESS" "Monthly Restore Test Successful:\n\n$DETAILS_BUFFER"
exit 0
