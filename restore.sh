#!/bin/bash
# ITFlow Docker Restore Script
# Restores database and uploads from backup

set -e

# Check if backup file is provided
if [ -z "$1" ]; then
    echo "Usage: ./restore.sh <backup-date>"
    echo "Example: ./restore.sh 20240209_143000"
    echo ""
    echo "Available backups:"
    ls -1 backups/ | grep -o '[0-9]\{8\}_[0-9]\{6\}' | sort -u
    exit 1
fi

BACKUP_DATE=$1
BACKUP_DIR="./backups"
BACKUP_PREFIX="itflow-backup-${BACKUP_DATE}"

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found"
    exit 1
fi

echo "=========================================="
echo "ITFlow Restore Starting"
echo "=========================================="
echo "Date: $(date)"
echo "Restoring from: ${BACKUP_DATE}"
echo ""

# Confirm action
read -p "⚠️  This will OVERWRITE current data. Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Restore cancelled"
    exit 0
fi

# Stop services
echo "🛑 Stopping services..."
docker-compose stop itflow itflow-cron

# 1. Restore Database
DB_BACKUP="${BACKUP_DIR}/${BACKUP_PREFIX}-database.sql.gz"
if [ -f "$DB_BACKUP" ]; then
    echo ""
    echo "📥 Restoring database..."
    
    # Drop and recreate database
    docker-compose exec -T db mysql -u root -p"${DB_ROOT_PASSWORD}" -e "DROP DATABASE IF EXISTS ${DB_NAME};"
    docker-compose exec -T db mysql -u root -p"${DB_ROOT_PASSWORD}" -e "CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
    
    # Import backup
    gunzip -c "$DB_BACKUP" | docker-compose exec -T db mysql -u root -p"${DB_ROOT_PASSWORD}" "${DB_NAME}"
    
    if [ $? -eq 0 ]; then
        echo "✅ Database restored successfully"
    else
        echo "❌ Database restore failed"
        exit 1
    fi
else
    echo "⚠️  Database backup not found: $DB_BACKUP"
fi

# 2. Restore Uploads
UPLOADS_BACKUP="${BACKUP_DIR}/${BACKUP_PREFIX}-uploads.tar.gz"
if [ -f "$UPLOADS_BACKUP" ]; then
    echo ""
    echo "📥 Restoring uploads..."
    
    # Backup current uploads (just in case)
    if [ -d "./uploads" ]; then
        mv uploads uploads.old.$(date +%s)
    fi
    
    # Extract backup
    tar xzf "$UPLOADS_BACKUP"
    
    echo "✅ Uploads restored successfully"
else
    echo "⚠️  Uploads backup not found: $UPLOADS_BACKUP"
fi

# 3. Restore Config
CONFIG_BACKUP="${BACKUP_DIR}/${BACKUP_PREFIX}-config.tar.gz"
if [ -f "$CONFIG_BACKUP" ]; then
    echo ""
    echo "📥 Restoring configuration..."
    
    # Backup current config
    if [ -d "./config" ]; then
        mv config config.old.$(date +%s)
    fi
    
    # Extract backup
    tar xzf "$CONFIG_BACKUP"
    
    echo "✅ Configuration restored successfully"
else
    echo "⚠️  Config backup not found: $CONFIG_BACKUP"
fi

# Fix permissions
echo ""
echo "🔧 Fixing permissions..."
docker-compose run --rm itflow chown -R www-data:www-data /var/www/html/uploads 2>/dev/null || true

# Start services
echo ""
echo "🚀 Starting services..."
docker-compose start itflow itflow-cron

echo ""
echo "=========================================="
echo "✅ Restore Completed Successfully!"
echo "=========================================="
echo ""
echo "Please verify the application is working correctly."
echo "Old data was backed up with .old.* extension"
