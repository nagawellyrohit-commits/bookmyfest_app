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

# Ensure required env variables are present
if [ -z "$BACKUP_BASE_DIR" ] || [ -z "$RESTIC_PASSWORD_FILE" ] || [ -z "$DATABASE_URL" ]; then
  echo "❌ Error: BACKUP_BASE_DIR, RESTIC_PASSWORD_FILE, and DATABASE_URL must be configured in .env"
  exit 1
fi

# Setup monthly log file
LOG_YEAR_MONTH=$(date +"%Y-%m")
LOG_FILE="$BACKUP_BASE_DIR/logs/backup-$LOG_YEAR_MONTH.log"
mkdir -p "$BACKUP_BASE_DIR/logs"
mkdir -p "$BACKUP_BASE_DIR/tmp"

# Helper for logging
log_message() {
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Concurrency lock protection using flock
LOCK_FILE="$BACKUP_BASE_DIR/tmp/backup.lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  log_message "❌ Error: Another backup process is already running. Exiting to avoid overlap."
  node "$SCRIPT_DIR/notify.js" "FAILED" "Another backup process is already running. Check for active cron jobs."
  exit 1
fi

log_message "🚀 Starting BookMyFest Scheduled Backup..."

# Initialize a details buffer for the email notification
DETAILS_BUFFER=""
append_details() {
  DETAILS_BUFFER="$DETAILS_BUFFER$1\n"
  log_message "$1"
}

# Export environment variables for Restic
export RESTIC_PASSWORD_FILE
export RESTIC_REPOSITORY="$BACKUP_BASE_DIR/repository"

# 1. Clear repository locks if any crashed lock remains (single VPS recoverability)
if command -v restic &> /dev/null; then
  append_details "Removing stale repository locks..."
  restic unlock &> /dev/null || true
fi

# 2. Database Backup & Compression
DB_DUMP_FILE="$BACKUP_BASE_DIR/tmp/db_backup.sql.gz"
append_details "Dumping and compressing PostgreSQL database..."

if ! pg_dump "$DATABASE_URL" | gzip > "$DB_DUMP_FILE"; then
  append_details "❌ Database dump command execution failed."
  node "$SCRIPT_DIR/notify.js" "FAILED" "$DETAILS_BUFFER"
  exit 1
fi

# 3. Database Dump Verification Checks
if [ ! -f "$DB_DUMP_FILE" ]; then
  append_details "❌ Database dump file does not exist."
  node "$SCRIPT_DIR/notify.js" "FAILED" "$DETAILS_BUFFER"
  exit 1
fi

FILE_SIZE=$(wc -c <"$DB_DUMP_FILE" | tr -d ' ')
if [ "$FILE_SIZE" -eq 0 ]; then
  append_details "❌ Database dump file is empty (0 bytes)."
  node "$SCRIPT_DIR/notify.js" "FAILED" "$DETAILS_BUFFER"
  exit 1
fi

if ! gzip -t "$DB_DUMP_FILE"; then
  append_details "❌ Database dump file failed gzip integrity check."
  node "$SCRIPT_DIR/notify.js" "FAILED" "$DETAILS_BUFFER"
  exit 1
fi

append_details "✅ Database dump verified successfully (Size: $FILE_SIZE bytes)."

# 4. Restic Backup Execution Setup
STORAGE_DIR="/var/www/bookmyfest_storage"
if [ ! -d "$STORAGE_DIR" ]; then
  append_details "⚠️ Warning: Storage directory $STORAGE_DIR does not exist. Creating storage root..."
  mkdir -p "$STORAGE_DIR"
fi

# 3.5 Generate backup metadata JSON file
METADATA_FILE="$BACKUP_BASE_DIR/tmp/metadata.json"
append_details "Generating backup metadata JSON file..."

APP_VERSION=$(node -e "import fs from 'fs'; console.log(JSON.parse(fs.readFileSync('$SCRIPT_DIR/../package.json')).version)" 2>/dev/null || echo "1.0.0")
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "N/A")
CREATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
HOSTNAME_VAL=$(hostname)
PG_VER=$(pg_dump --version 2>/dev/null | head -n 1 || echo "Unknown")
NODE_VER=$(node --version 2>/dev/null || echo "Unknown")
RESTIC_VER=$(restic version 2>/dev/null | head -n 1 || echo "Unknown")
OS_VAL=$(lsb_release -ds 2>/dev/null || uname -srm)
STORAGE_SIZE_BYTES=$(du -sk "$STORAGE_DIR" 2>/dev/null | awk '{print $1 * 1024}' || echo "0")

cat <<EOF > "$METADATA_FILE"
{
  "backup_schema": 1,
  "application": "BookMyFest",
  "app_version": "$APP_VERSION",
  "git_commit": "$GIT_COMMIT",
  "created_at": "$CREATED_AT",
  "hostname": "$HOSTNAME_VAL",
  "postgres_version": "$PG_VER",
  "node_version": "$NODE_VER",
  "restic_version": "$RESTIC_VER",
  "backup_type": "daily",
  "os": "$OS_VAL",
  "database_size_bytes": $FILE_SIZE,
  "storage_size_bytes": $STORAGE_SIZE_BYTES
}
EOF

append_details "✅ Metadata JSON generated: $(cat "$METADATA_FILE")"

append_details "Executing Restic backup..."

BACKUP_COMMAND="restic backup \
  --tag daily \
  --host \$(hostname) \
  --exclude \"*.tmp\" \
  --exclude \"*.log\" \
  \"$DB_DUMP_FILE\" \
  \"$METADATA_FILE\" \
  \"$STORAGE_DIR\""

# Run backup and capture output details
BACKUP_OUTPUT=$(eval "$BACKUP_COMMAND" 2>&1)
BACKUP_STATUS=$?

if [ $BACKUP_STATUS -ne 0 ]; then
  append_details "❌ Restic backup failed."
  append_details "Details:\n$BACKUP_OUTPUT"
  rm -f "$DB_DUMP_FILE"
  rm -f "$METADATA_FILE"
  node "$SCRIPT_DIR/notify.js" "FAILED" "$DETAILS_BUFFER"
  exit 1
fi

# Extract metadata stats from restic output
SNAPSHOT_ID=$(echo "$BACKUP_OUTPUT" | grep -oE "snapshot [a-f0-9]+ saved" | awk '{print $2}' || true)
if [ -z "$SNAPSHOT_ID" ]; then
  SNAPSHOT_ID=$(echo "$BACKUP_OUTPUT" | grep -i "saved" | awk '/snapshot/ {print $2}' || true)
fi
STATS_LINE=$(echo "$BACKUP_OUTPUT" | grep -E "processed [0-9]+ files" | tr -d '\r' || true)

append_details "✅ Restic backup finished successfully."
if [ -n "$SNAPSHOT_ID" ]; then
  append_details "Snapshot ID: $SNAPSHOT_ID"
fi
if [ -n "$STATS_LINE" ]; then
  append_details "Statistics: $STATS_LINE"
fi
append_details "Restic full log output:\n$BACKUP_OUTPUT"

# 5. Enforce Retention Policy & Pruning
append_details "Enforcing retention policy (20 daily, 8 weekly, 12 monthly)..."
RETENTION_OUTPUT=$(restic forget --keep-daily 20 --keep-weekly 8 --keep-monthly 12 --prune 2>&1)
RETENTION_STATUS=$?

if [ $RETENTION_STATUS -eq 0 ]; then
  append_details "✅ Retention and pruning completed successfully."
  append_details "Retention details:\n$RETENTION_OUTPUT"
else
  append_details "⚠️ Warning: Retention policy enforcement failed."
  append_details "Details:\n$RETENTION_OUTPUT"
fi

# Clean up database dump and metadata file
rm -f "$DB_DUMP_FILE"
rm -f "$METADATA_FILE"

log_message "🎉 Backup process completed successfully!"
node "$SCRIPT_DIR/notify.js" "SUCCESS" "$DETAILS_BUFFER"
exit 0
