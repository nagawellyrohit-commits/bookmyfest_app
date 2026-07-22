# BookMyFest Server Backup & Disaster Recovery Guide

This guide describes how to configure, run, and restore backups for the BookMyFest production server using the Restic backup utility.

---

## 📁 System Layout

### Version-Controlled Code
```text
/var/www/bookmyfest_app/server/scripts/
├── setup-backup.sh        # Run once to initialize restic repository
├── backup.sh              # Scheduled daily backup run
├── restore.sh             # Interactive database & storage restore
├── verify-backup.sh       # Repository verification utility
└── notify.js              # Dispatches success/failure email notifications
```

### Server Runtime Storage
```text
/var/www/bookmyfest_backups/
├── repository/            # Encrypted restic repository files
├── tmp/                   # Temp database dumps and concurrency locks
├── logs/                  # Log rotation files
│   ├── backup-YYYY-MM.log
│   ├── restore-YYYY-MM.log
│   └── verify-YYYY-MM.log
└── restic-password        # Secure password file (chmod 600)
```

---

## 🚀 One-Time Setup (New VPS)

### 1. Install Restic
Ensure `restic` and `gzip` are installed on your VPS:
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y restic gzip postgresql-client

# macOS
brew install restic
```

### 2. Configure Environment Variables
Verify your server's `.env` configuration file contains:
```env
BACKUP_BASE_DIR=/var/www/bookmyfest_backups
RESTIC_PASSWORD_FILE=/var/www/bookmyfest_backups/restic-password
BACKUP_ADMIN_EMAIL=support@bookmyfest.co
DATABASE_URL="postgresql://user:pass@localhost:5432/dbname"
```

### 3. Run the Initialization Script
Execute the setup script to create directories and initialize the encrypted repository:
```bash
cd /var/www/bookmyfest_app/server
./scripts/setup-backup.sh
```

---

## 📅 Scheduling Backups (Cron setup)

Configure automated backup execution using cron:
```bash
crontab -e
```

Add the following schedules:

```text
# 1. Run daily backup at 2:00 AM
0 2 * * * /var/www/bookmyfest_app/server/scripts/backup.sh >> /var/www/bookmyfest_backups/logs/cron-backup.log 2>&1

# 2. Run weekly lightweight repository check on Sunday at 3:00 AM
0 3 * * 0 /var/www/bookmyfest_app/server/scripts/verify-backup.sh >> /var/www/bookmyfest_backups/logs/cron-verify.log 2>&1

# 3. Run monthly full cryptographic verification on the 1st of the month at 4:00 AM
0 4 1 * * /var/www/bookmyfest_app/server/scripts/verify-backup.sh --full >> /var/www/bookmyfest_backups/logs/cron-verify-full.log 2>&1

# 4. Run monthly restore test on the 1st of the month at 4:30 AM
30 4 1 * * /var/www/bookmyfest_app/server/scripts/test-restore.sh >> /var/www/bookmyfest_backups/logs/cron-test-restore.log 2>&1
```

---

## 🔒 Lock Management & Concurrency
- `backup.sh` enforces exclusive execution using `flock`.
- Stale locks left behind by interrupted operations (such as VPS crashes) are automatically removed using:
  ```bash
  restic unlock
  ```

---

## 🔄 Disaster Recovery: Restore Steps

### 1. List Available Snapshots
```bash
./scripts/restore.sh --list
```

### 2. Dry-Run Check (Verify files inside a snapshot)
Before restoring, view the content list of a snapshot without modifying your database or files:
```bash
./scripts/restore.sh --dry-run latest
# or by snapshot ID
./scripts/restore.sh --dry-run 4d2e9f
```

### 3. Run Restore
To restore database schema, data, and uploads:
```bash
# Restore latest snapshot interactively (asks for confirmation)
./scripts/restore.sh latest

# Restore latest snapshot non-interactively (ideal for automated scenarios)
./scripts/restore.sh latest --force

# Or restore specific snapshot ID
./scripts/restore.sh 4d2e9f
./scripts/restore.sh 4d2e9f --force
```
```

---

## 🔐 Changing the Restic Password
If you need to rotate the encryption password:
1. Generate / change the password in Restic:
   ```bash
   restic -r /var/www/bookmyfest_backups/repository --password-file /var/www/bookmyfest_backups/restic-password key add
   ```
2. Update the password content inside the file `/var/www/bookmyfest_backups/restic-password`.
3. Revoke/remove the old key from the repository using `restic key remove <key-id>`.
