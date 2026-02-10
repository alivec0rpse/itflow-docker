---
layout: default
title: Quick Start Guide
---

# Quick Start Guide

Get ITFlow running in 5 minutes.

## Prerequisites

- Docker and Docker Compose installed
- 2GB+ RAM available
- Open ports: 80 (web), 3306 (optional database access)

## Setup

### 1. Clone and Configure

```bash
git clone https://github.com/alivec0rpse/itflow-docker.git
cd itflow-docker
cp .env.example .env
```

Edit `.env` and set:
```bash
DB_PASSWORD=your_secure_password_here
DB_ROOT_PASSWORD=your_root_password_here
BASE_URL=http://localhost  # or your domain
```

### 2. Deploy

```bash
docker-compose up -d
```

The database will auto-initialize (takes ~30 seconds). Check status:
```bash
docker-compose logs -f itflow
```

### 3. Complete Setup

Visit `http://localhost` and complete the web setup wizard:
- Create admin account
- Configure company details
- Set timezone and preferences

**IMPORTANT**: After setup, disable the wizard:
```bash
# Edit .env
ENABLE_SETUP=0

# Restart
docker-compose restart itflow
```

## Next Steps

- [Configure SSL](deployment#ssl-setup)
- [Setup automated backups](backup)
- [Review security settings](deployment#security)

## Common Commands

```bash
# View logs
docker-compose logs -f itflow

# Restart services
docker-compose restart

# Backup database
./backup.sh

# Access shell
docker-compose exec itflow bash

# Stop everything
docker-compose down
```

## Troubleshooting

Having issues? Check the [Troubleshooting Guide](troubleshooting).
