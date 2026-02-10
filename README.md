# ITFlow Docker

Production-ready Docker setup for [ITFlow](https://github.com/itflow-org/itflow) - an open-source IT documentation and ticketing platform for MSPs.

## Documentation

**[📖 Full Documentation](https://alivec0rpse.github.io/itflow-docker/)**

- [Quick Start Guide](https://alivec0rpse.github.io/itflow-docker/quickstart)
- [Deployment Guide](https://alivec0rpse.github.io/itflow-docker/deployment)
- [Backup & Restore](https://alivec0rpse.github.io/itflow-docker/backup)
- [Troubleshooting](https://alivec0rpse.github.io/itflow-docker/troubleshooting)

## Features

- **Zero-config deployment** - Database schema auto-imports on first run
- **Environment-based configuration** - Everything configured via `.env` file
- **Production ready** - Security headers, health checks, automated backups
- **Multi-service** - Web, cron jobs, MariaDB, optional nginx/phpMyAdmin

## Quick Start

```bash
# Clone and configure
git clone <your-repo-url>
cd itflow-docker
cp .env.example .env
nano .env  # Set your passwords and BASE_URL

# Deploy
docker-compose up -d

# Check status
docker-compose ps
```

Visit `http://localhost` and complete the setup wizard. After setup, set `ENABLE_SETUP=0` in `.env` and restart.

## Requirements

- Docker Engine 20.10+
- Docker Compose V2
- 2GB RAM minimum
- 10GB disk space

## Architecture

```
┌─────────┐      ┌──────────┐      ┌─────────┐
│  Nginx  │─────▶│  ITFlow  │─────▶│ MariaDB │
│ (optional)     │   Web    │      │         │
└─────────┘      └──────────┘      └─────────┘
                       │
                 ┌─────┴──────┐
                 │ ITFlow Cron │
                 └────────────┘
```

**Services:**
- `itflow` - Apache + PHP web application
- `itflow-cron` - Background tasks (email, domain checks, etc)
- `db` - MariaDB 10.11 database
- `nginx` - Optional SSL reverse proxy (profile: nginx)
- `phpmyadmin` - Optional database management (profile: tools)

## Configuration

Key environment variables in `.env`:

```bash
# Database (CHANGE THESE!)
DB_PASSWORD=your_secure_password
DB_ROOT_PASSWORD=your_root_password

# Application
APP_NAME=ITFlow
BASE_URL=https://yourdomain.com
HTTPS_ONLY=true
TZ=America/New_York

# Security
ENABLE_SETUP=1  # Set to 0 after initial setup!
SESSION_TIMEOUT=3600
```

Generate strong passwords:
```bash
openssl rand -base64 32
```

## Common Commands

```bash
# Start/stop
docker-compose up -d
docker-compose down

# View logs
docker-compose logs -f itflow

# Backup
./backup.sh

# Restore
./restore.sh backup-file.tar.gz

# Shell access
docker-compose exec itflow bash
```

Or use the Makefile:
```bash
make up
make logs
make backup
make shell
```

## Backups

Automatic backup script included:

```bash
# Manual backup
./backup.sh

# Schedule with cron (daily at 2 AM)
0 2 * * * /path/to/itflow-docker/backup.sh
```

Backups include database, uploads, and configuration. Default retention: 30 days.

## Production Checklist

Before deploying to production:

- [ ] Change default passwords in `.env`
- [ ] Set `BASE_URL` to your domain
- [ ] Set `HTTPS_ONLY=true`
- [ ] Configure SSL certificates (if using nginx)
- [ ] Complete setup wizard
- [ ] Set `ENABLE_SETUP=0` and restart
- [ ] Test backup/restore procedures
- [ ] Setup automated backups

## Security Notes

- All containers run as `www-data` (non-root)
- Security headers enabled
- PHP execution blocked in uploads directory
- Session security configured
- Database accessible only from containers (no external exposure)

For production, also consider:
- Enable firewall (allow only 80, 443)
- Setup fail2ban for brute force protection
- Regular updates (`git pull` in itflow-master + rebuild)
- Monitor logs for suspicious activity

## Updating

```bash
# Pull latest ITFlow code
cd itflow-master && git pull && cd ..

# Rebuild and restart
docker-compose build
docker-compose up -d
```

Health checks ensure zero downtime during updates.

## Troubleshooting

**Container won't start:**
```bash
docker-compose logs itflow
```

**Database connection errors:**
```bash
docker-compose exec itflow mysqladmin ping -h db -u itflow -p
```

**Reset everything:**
```bash
docker-compose down -v
rm -rf uploads/* logs/* config/*
docker-compose up -d
```

**Permission issues:**
```bash
docker-compose exec itflow chown -R www-data:www-data /var/www/html/uploads
```

## File Structure

```
itflow-docker/
├── docker-compose.yml       # Service orchestration
├── Dockerfile              # Multi-stage build
├── .env                    # Your configuration (not in git)
├── backup.sh               # Backup automation
├── restore.sh              # Restore script
├── Makefile                # Convenience commands
├── docker/                 # Docker configs
│   ├── entrypoint.sh       # Container initialization
│   ├── apache/itflow.conf  # Apache config
│   ├── php/php-prod.ini    # PHP settings
│   ├── mysql/mysql.cnf     # MariaDB config
│   ├── cron/itflow-cron    # Cron jobs
│   └── nginx/nginx.conf    # Nginx config
├── itflow-master/          # ITFlow application
├── uploads/                # User uploads (persistent)
├── logs/                   # Application logs
├── config/                 # Generated config files
└── backups/                # Backup storage
```

## Support

- **ITFlow Documentation:** https://docs.itflow.org
- **ITFlow Forum:** https://forum.itflow.org
- **ITFlow GitHub:** https://github.com/itflow-org/itflow

## License

This Docker setup is provided as-is. ITFlow itself is licensed under GPLv3.
