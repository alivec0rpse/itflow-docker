---
layout: default
title: Backup & Restore
---

# Backup & Restore

Complete guide to backing up and restoring your ITFlow installation.

## Quick Backup

```bash
./backup.sh
```

Backups are stored in `backups/` with timestamp naming:
```
backups/
├── itflow-backup-20240210_140530-database.sql.gz
├── itflow-backup-20240210_140530-uploads.tar.gz
└── itflow-backup-20240210_140530-config.tar.gz
```

## What Gets Backed Up

1. **Database**: Complete MySQL dump with all tables and data
2. **Uploads**: User-uploaded files (tickets, documents, client files)
3. **Configuration**: Generated `config.php` and other settings

## Automated Backups

### Setup Daily Backups

```bash
# Make script executable
chmod +x backup.sh

# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * cd /opt/itflow-docker && ./backup.sh >> /var/log/itflow-backup.log 2>&1
```

### Retention Policy

Default: 30 days (configurable in `.env`):
```bash
BACKUP_RETENTION_DAYS=30
```

Backups older than this are automatically deleted.

## Offsite Backups

### Option 1: rsync to Remote Server

```bash
#!/bin/bash
# /opt/scripts/offsite-backup.sh

rsync -avz --delete \
  /opt/itflow-docker/backups/ \
  user@backup-server:/backups/itflow/
```

Add to crontab:
```bash
30 2 * * * /opt/scripts/offsite-backup.sh
```

### Option 2: AWS S3

```bash
#!/bin/bash
# Install: apt install awscli

aws s3 sync /opt/itflow-docker/backups/ \
  s3://my-bucket/itflow-backups/ \
  --delete
```

### Option 3: Backblaze B2

```bash
#!/bin/bash
# Install: pip install b2

b2 sync /opt/itflow-docker/backups/ \
  b2://my-bucket/itflow-backups/
```

## Restore Procedure

### Full Restore

```bash
./restore.sh 20240210_140530
```

This will:
1. Stop ITFlow services
2. Drop and recreate database
3. Import backup data
4. Restore uploaded files
5. Restore configuration
6. Fix permissions
7. Restart services

### Confirmation Required

The script will ask for confirmation:
```
⚠️  WARNING: This will OVERWRITE your current installation!

Backup date: 20240210_140530
Database backup: found
Uploads backup: found
Config backup: found

Continue? (yes/no):
```

Type `yes` to proceed.

## Manual Backup

### Database Only

```bash
docker-compose exec -T db mysqldump \
  -u root -p"${DB_ROOT_PASSWORD}" \
  --single-transaction \
  itflow | gzip > manual-backup.sql.gz
```

### Uploads Only

```bash
tar czf manual-uploads.tar.gz uploads/
```

### Full Manual Backup

```bash
# Database
docker-compose exec -T db mysqldump \
  -u root -p"${DB_ROOT_PASSWORD}" \
  itflow | gzip > db.sql.gz

# Files
tar czf uploads.tar.gz uploads/
tar czf config.tar.gz config/
tar czf logs.tar.gz logs/
```

## Manual Restore

### Database Restore

```bash
# Stop services
docker-compose stop itflow itflow-cron

# Drop database
docker-compose exec -T db mysql \
  -u root -p"${DB_ROOT_PASSWORD}" \
  -e "DROP DATABASE IF EXISTS itflow; CREATE DATABASE itflow;"

# Import backup
gunzip -c backup.sql.gz | \
  docker-compose exec -T db mysql \
  -u root -p"${DB_ROOT_PASSWORD}" \
  itflow

# Start services
docker-compose start itflow itflow-cron
```

### Files Restore

```bash
# Stop services
docker-compose stop itflow itflow-cron

# Extract backups
tar xzf uploads.tar.gz
tar xzf config.tar.gz

# Fix permissions
docker-compose exec itflow chown -R www-data:www-data /var/www/html/uploads
docker-compose exec itflow chmod -R 775 /var/www/html/uploads

# Start services
docker-compose start itflow itflow-cron
```

## Testing Backups

**IMPORTANT**: Test your backups regularly!

### Monthly Test Procedure

1. Spin up a test environment:
```bash
# Create test directory
mkdir /tmp/itflow-test
cd /tmp/itflow-test

# Copy docker setup
cp -r /opt/itflow-docker/{docker-compose.yml,.env,docker,backup.sh,restore.sh} .

# Copy latest backup
cp /opt/itflow-docker/backups/itflow-backup-* .
```

2. Restore backup in test environment:
```bash
./restore.sh <backup-date>
```

3. Verify:
```bash
# Check services
docker-compose ps

# Access web interface
curl -f http://localhost/

# Login and verify data
```

4. Cleanup:
```bash
docker-compose down -v
cd /
rm -rf /tmp/itflow-test
```

## Backup Best Practices

1. **Automate Everything**: Use cron for scheduled backups
2. **Test Monthly**: Restore to a test environment every month
3. **Offsite Storage**: Keep backups in multiple locations
4. **Monitor Success**: Check backup logs regularly
5. **Document Procedures**: Keep restore instructions accessible
6. **Encrypt Sensitive Backups**: Use GPG for encryption:

```bash
# Encrypt
gpg --symmetric --cipher-algo AES256 backup.sql.gz

# Decrypt  
gpg --decrypt backup.sql.gz.gpg > backup.sql.gz
```

## Quick Reference

```bash
# Backup
./backup.sh

# Restore
./restore.sh <backup-date>

# List backups
ls -lh backups/

# Backup size
du -sh backups/

# Test latest backup
LATEST=$(ls -t backups/ | grep database | head -1 | cut -d'-' -f3)
./restore.sh $LATEST

# Clean old backups (older than 30 days)
find backups/ -name "itflow-backup-*" -mtime +30 -delete
```

## Troubleshooting

### Backup Script Fails

Check permissions:
```bash
chmod +x backup.sh
ls -la backup.sh
```

Check docker access:
```bash
docker-compose ps
```

### Restore Fails

Check backup files exist:
```bash
ls -la backups/itflow-backup-<date>-*
```

Check file integrity:
```bash
gunzip -t backup.sql.gz
tar tzf backup.tar.gz > /dev/null
```

### Database Import Errors

Check error log:
```bash
docker-compose logs db
```

Try manual import with verbose output:
```bash
gunzip -c backup.sql.gz | \
  docker-compose exec -T db mysql \
  -u root -p"${DB_ROOT_PASSWORD}" \
  --verbose itflow
```

## Support

Having issues? Check the [Troubleshooting Guide](troubleshooting) or open an issue on [GitHub](https://github.com/alivec0rpse/itflow-docker/issues).
