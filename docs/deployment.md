---
layout: default
title: Deployment Guide
---

# Deployment Guide

Production deployment checklist and procedures.

## Server Requirements

- Ubuntu 20.04+ or Debian 11+ recommended
- 4GB+ RAM (8GB+ for production)
- 20GB+ disk space
- Docker 20.10+ and Docker Compose 2.0+

## Pre-Deployment Checklist

### 1. Server Setup

```bash
# Update system
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
systemctl enable docker
systemctl start docker

# Install Docker Compose
apt install docker-compose-plugin -y
```

### 2. Security Hardening

```bash
# Configure firewall
ufw allow 22/tcp   # SSH
ufw allow 80/tcp   # HTTP
ufw allow 443/tcp  # HTTPS
ufw enable

# Create non-root user
adduser itflow
usermod -aG docker itflow
```

### 3. Configuration

Clone the repository:
```bash
cd /opt
git clone https://github.com/alivec0rpse/itflow-docker.git
cd itflow-docker
cp .env.example .env
```

Edit `.env` with production values:
```bash
# Strong passwords (use: openssl rand -base64 32)
DB_PASSWORD=<generated_password>
DB_ROOT_PASSWORD=<generated_password>

# Your domain
BASE_URL=https://itflow.yourdomain.com
HTTPS_ONLY=true

# Timezone
TZ=America/New_York

# Disable database external access
# Comment out or remove DB_PORT_EXTERNAL
```

## SSL Setup

### Option 1: Let's Encrypt (Recommended)

```bash
# Install Certbot
apt install certbot -y

# Obtain certificate
certbot certonly --standalone -d itflow.yourdomain.com

# Certificates will be in:
# /etc/letsencrypt/live/itflow.yourdomain.com/
```

Create symlinks:
```bash
mkdir -p docker/nginx/ssl
ln -s /etc/letsencrypt/live/itflow.yourdomain.com/fullchain.pem docker/nginx/ssl/cert.pem
ln -s /etc/letsencrypt/live/itflow.yourdomain.com/privkey.pem docker/nginx/ssl/key.pem
```

Enable Nginx profile:
```bash
docker-compose --profile nginx up -d
```

### Option 2: Custom Certificates

Place certificates in `docker/nginx/ssl/`:
```bash
docker/nginx/ssl/cert.pem  # Full chain
docker/nginx/ssl/key.pem   # Private key
```

## Deployment

### 1. Initial Deploy

```bash
docker-compose build
docker-compose up -d
```

### 2. Verify Services

```bash
# Check status
docker-compose ps

# All services should show (healthy)
# - itflow
# - itflow-cron  
# - db
```

### 3. Complete Web Setup

Visit your domain and complete the setup wizard. Then **immediately disable it**:

```bash
# Edit .env
ENABLE_SETUP=0

# Apply
docker-compose restart itflow
```

## Automated Backups

### Setup Daily Backups

```bash
# Make backup script executable
chmod +x backup.sh

# Add to crontab
crontab -e
```

Add this line:
```bash
0 2 * * * cd /opt/itflow-docker && ./backup.sh >> /var/log/itflow-backup.log 2>&1
```

### Backup Storage

Backups are stored in `backups/` directory. Consider:
- Offsite backup via rsync/rclone
- S3/B2 storage for disaster recovery
- Retention: Default 30 days (configurable in `.env`)

Test your backups monthly:
```bash
./restore.sh <backup-date>
```

## Monitoring

### Health Checks

```bash
# Application
curl -f http://localhost/

# Database
docker-compose exec db mysqladmin ping -u root -p
```

### Logs

```bash
# Real-time logs
docker-compose logs -f

# Specific service
docker-compose logs -f itflow

# Cron jobs
docker-compose exec itflow-cron tail -f /var/log/cron.log
```

### Uptime Monitoring

Consider external monitoring services:
- UptimeRobot (free)
- Pingdom
- StatusCake

Monitor URL: `https://itflow.yourdomain.com/keepalive.php`

## Updates

### Updating ITFlow

```bash
cd /opt/itflow-docker/itflow-master
git pull

# Rebuild and restart
cd ..
docker-compose build itflow itflow-cron
docker-compose up -d
```

### Updating Docker Images

```bash
docker-compose pull
docker-compose up -d
```

## Security Hardening

### 1. Remove Database External Access

In `docker-compose.yml`, remove from `db` service:
```yaml
ports:
  - "${DB_PORT_EXTERNAL:-3306}:3306"  # DELETE THIS
```

### 2. Enable HTTPS Only

In `.env`:
```bash
HTTPS_ONLY=true
BASE_URL=https://itflow.yourdomain.com
```

### 3. Regular Updates

```bash
# System updates
apt update && apt upgrade -y

# Docker updates
docker-compose pull
docker-compose up -d
```

### 4. Password Rotation

Change database passwords every 90 days:
```bash
# Update .env with new passwords
docker-compose down
docker-compose up -d
```

## Performance Tuning

### For High-Traffic Deployments

Edit `docker/mysql/mysql.cnf`:
```ini
[mysqld]
innodb_buffer_pool_size = 2G  # 50-70% of available RAM
max_connections = 200
```

Edit `docker/php/php-prod.ini`:
```ini
memory_limit = 1024M
opcache.memory_consumption = 512
```

Restart after changes:
```bash
docker-compose restart
```

## Troubleshooting

Common issues and solutions:

### Port Conflicts
```bash
# Check what's using port 80
netstat -tulpn | grep :80

# Change port in .env
WEB_PORT=8080
docker-compose up -d
```

### Permission Errors
```bash
docker-compose exec itflow chown -R www-data:www-data /var/www/html/uploads
docker-compose exec itflow chmod -R 775 /var/www/html/uploads
```

### Database Connection Failed
```bash
# Check database is running
docker-compose ps db

# View logs
docker-compose logs db

# Restart services
docker-compose restart
```

More help: [Troubleshooting Guide](troubleshooting)

## Support

- [GitHub Issues](https://github.com/alivec0rpse/itflow-docker/issues)
- [ITFlow Forum](https://forum.itflow.org)
- [ITFlow Documentation](https://docs.itflow.org)
