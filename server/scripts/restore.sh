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
if [ -z "$BACKUP_BASE_DIR" ] || [ -z "$RESTIC_PASSWORD_FILE" ] || [ -z "$DATABASE_URL" ]; then
  echo "❌ Error: BACKUP_BASE_DIR, RESTIC_PASSWORD_FILE, and DATABASE_URL must be configured in .env"
  exit 1
fi

# Setup monthly log file
LOG_YEAR_MONTH=$(date +"%Y-%m")
LOG_FILE="$BACKUP_BASE_DIR/logs/restore-$LOG_YEAR_MONTH.log"
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

# 1. Option: --list
if [ "$1" = "--list" ]; then
  echo "📋 Listing all available backup snapshots:"
  restic snapshots
  exit 0
fi

# 2. Option: --dry-run
if [ "$1" = "--dry-run" ]; then
  SNAPSHOT_ID="$2"
  if [ -z "$SNAPSHOT_ID" ]; then
    echo "❌ Error: Please specify a snapshot ID. Example: restore.sh --dry-run latest or restore.sh --dry-run 4d2e9f"
    exit 1
  fi
  echo "🔍 Dry-run: Simulating restore for snapshot '$SNAPSHOT_ID'..."
  echo "Below are the files contained in this snapshot that would be restored:"
  echo "------------------------------------------------------------"
  restic ls "$SNAPSHOT_ID"
  echo "------------------------------------------------------------"
  echo "✅ Dry-run completed. No files were modified."
  exit 0
fi

# 3. Restore Option execution
SNAPSHOT_ID="$1"
FORCE_RESTORE="$2"

if [ -z "$SNAPSHOT_ID" ]; then
  echo "ℹ️ Usage instructions:"
  echo "  restore.sh --list                    - List all snapshots"
  echo "  restore.sh --dry-run <snapshot-id>   - Show files inside a snapshot without restoring"
  echo "  restore.sh latest                    - Restore database and storage from the latest snapshot"
  echo "  restore.sh latest --force            - Restore database and storage from the latest snapshot non-interactively"
  echo "  restore.sh <snapshot-id>             - Restore database and storage from a specific snapshot"
  echo "  restore.sh <snapshot-id> --force    - Restore database and storage from a specific snapshot non-interactively"
  exit 1
fi

log_message "⚠️ WARNING: You are starting a RESTORE from snapshot '$SNAPSHOT_ID'."
log_message "This will overwrite your database and storage files with the snapshot data."

if [ "$FORCE_RESTORE" != "--force" ]; then
  read -p "Are you absolutely sure you want to proceed? (y/N): " CONFIRMATION
  if [ "$CONFIRMATION" != "y" ] && [ "$CONFIRMATION" != "Y" ]; then
    log_message "❌ Restore cancelled by user."
    exit 0
  fi
else
  log_message "ℹ️ --force flag supplied. Bypassing interactive confirmation prompt."
fi

log_message "🔄 Initialising restore process..."

# Create clean temporary directory for restoring
TEMP_RESTORE_DIR="$BACKUP_BASE_DIR/tmp/restore_run"
rm -rf "$TEMP_RESTORE_DIR"
mkdir -p "$TEMP_RESTORE_DIR"

log_message "Restoring snapshot files to temporary directory..."
if ! restic restore "$SNAPSHOT_ID" --target "$TEMP_RESTORE_DIR"; then
  log_message "❌ Restic restore command failed."
  rm -rf "$TEMP_RESTORE_DIR"
  exit 1
fi

# Locate the restored database dump and storage path
# Inside TEMP_RESTORE_DIR, it will recreate paths like:
# TEMP_RESTORE_DIR/var/www/bookmyfest_backups/tmp/db_backup.sql.gz
# TEMP_RESTORE_DIR/var/www/bookmyfest_storage/
RESTORED_DB_DUMP=$(find "$TEMP_RESTORE_DIR" -name "db_backup.sql.gz" | head -n 1)
RESTORED_STORAGE_ROOT=$(find "$TEMP_RESTORE_DIR" -path "*/var/www/bookmyfest_storage" | head -n 1)

# Import restored database
if [ -n "$RESTORED_DB_DUMP" ] && [ -f "$RESTORED_DB_DUMP" ]; then
  log_message "✅ Found restored database dump. Re-importing into PostgreSQL database..."
  # Clean up / drop schema to ensure clean slate
  log_message "Dropping existing public schema database tables..."
  psql "$DATABASE_URL" -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" &> /dev/null || true
  
  if gunzip -c "$RESTORED_DB_DUMP" | psql "$DATABASE_URL"; then
    log_message "✅ Database import completed successfully!"
  else
    log_message "❌ Database import failed. Check PostgreSQL connection configurations."
  fi
else
  log_message "⚠️ Warning: Restored database dump not found in snapshot."
fi

# Import restored storage root
TARGET_STORAGE_DIR="/var/www/bookmyfest_storage"
if [ -n "$RESTORED_STORAGE_ROOT" ] && [ -d "$RESTORED_STORAGE_ROOT" ]; then
  log_message "✅ Found restored storage files. Copying to $TARGET_STORAGE_DIR..."
  mkdir -p "$TARGET_STORAGE_DIR"
  cp -R "$RESTORED_STORAGE_ROOT/." "$TARGET_STORAGE_DIR/"
  log_message "✅ Storage files restored successfully!"
else
  log_message "⚠️ Warning: Restored storage directories not found in snapshot."
fi

# Clean up temp restore directory
rm -rf "$TEMP_RESTORE_DIR"
log_message "🎉 Restore process completed successfully!"
exit 0
