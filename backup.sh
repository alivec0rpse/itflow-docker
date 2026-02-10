#!/bin/bash
# ITFlow Docker Backup Script
# Backs up database and uploads directory

set -e

# Configuration
BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="itflow-backup-${DATE}"

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "=========================================="
echo "ITFlow Backup Starting"
echo "=========================================="
echo "Date: $(date)"
echo "Backup Directory: $BACKUP_DIR"
echo ""

# Stop cron to prevent writes during backup (optional)
# docker-compose stop itflow-cron

# 1. Backup Database
echo "📦 Backing up database..."
docker-compose exec -T db mysqldump \
    -u root \
    -p"${DB_ROOT_PASSWORD}" \
    --single-transaction \
    --quick \
    --lock-tables=false \
    "${DB_NAME}" > "${BACKUP_DIR}/${BACKUP_NAME}-database.sql"

if [ $? -eq 0 ]; then
    echo "✅ Database backup completed: ${BACKUP_NAME}-database.sql"
    # Compress database backup
    gzip "${BACKUP_DIR}/${BACKUP_NAME}-database.sql"
    echo "✅ Database backup compressed"
else
    echo "❌ Database backup failed"
    exit 1
fi

# 2. Backup Uploads
echo ""
echo "📦 Backing up uploads directory..."
if [ -d "./uploads" ]; then
    tar czf "${BACKUP_DIR}/${BACKUP_NAME}-uploads.tar.gz" uploads/
    echo "✅ Uploads backup completed: ${BACKUP_NAME}-uploads.tar.gz"
else
    echo "⚠️  No uploads directory found"
fi

# 3. Backup Config
echo ""
echo "📦 Backing up configuration..."
if [ -d "./config" ]; then
    tar czf "${BACKUP_DIR}/${BACKUP_NAME}-config.tar.gz" config/
    echo "✅ Config backup completed: ${BACKUP_NAME}-config.tar.gz"
else
    echo "⚠️  No config directory found"
fi

# 4. Backup .env file
echo ""
echo "📦 Backing up environment file..."
if [ -f ".env" ]; then
    cp .env "${BACKUP_DIR}/${BACKUP_NAME}.env"
    echo "✅ Environment file backed up: ${BACKUP_NAME}.env"
fi

# Restart cron if it was stopped
# docker-compose start itflow-cron

# Calculate sizes
echo ""
echo "=========================================="
echo "Backup Summary"
echo "=========================================="
ls -lh "${BACKUP_DIR}/${BACKUP_NAME}"* 2>/dev/null | awk '{print $9, "-", $5}'

# Clean old backups (keep last 30 days)
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}
echo ""
echo "🧹 Cleaning backups older than ${RETENTION_DAYS} days..."
find "$BACKUP_DIR" -name "itflow-backup-*" -type f -mtime +${RETENTION_DAYS} -delete
echo "✅ Old backups cleaned"

echo ""
echo "=========================================="
echo "✅ Backup Completed Successfully!"
echo "=========================================="
echo "Backup location: ${BACKUP_DIR}/${BACKUP_NAME}*"
echo ""

# Optional: Upload to remote storage
# Uncomment and configure for S3, rsync, etc.
# aws s3 cp "${BACKUP_DIR}/${BACKUP_NAME}-database.sql.gz" s3://your-bucket/itflow-backups/
# rsync -avz "${BACKUP_DIR}/${BACKUP_NAME}"* user@backup-server:/backups/itflow/
