---
layout: default
title: ITFlow Docker Documentation
---

# ITFlow Docker Documentation

Production-ready Docker setup for ITFlow - an open-source IT documentation and ticketing platform.

## Quick Links

- [Quick Start Guide](quickstart)
- [Deployment Guide](deployment)
- [Backup & Restore](backup)
- [Troubleshooting](troubleshooting)
- [GitHub Repository](https://github.com/alivec0rpse/itflow-docker)

## What is ITFlow?

ITFlow is a comprehensive IT documentation, ticketing, and accounting platform designed for Managed Service Providers (MSPs). This Docker setup provides:

- **One-command deployment** with automatic database initialization
- **Environment-based configuration** for easy management
- **Production-ready** security and performance optimizations
- **Automated backups** with built-in restore functionality
- **Background task processing** via dedicated cron container

## Architecture

```
┌─────────────────┐      ┌──────────────┐      ┌─────────────┐
│   Nginx (443)   │─────▶│  ITFlow (80) │─────▶│  MariaDB    │
│  (Optional SSL) │      │   + Apache   │      │   (3306)    │
└─────────────────┘      └──────────────┘      └─────────────┘
                                │
                         ┌──────┴────────┐
                         │   ITFlow Cron │
                         │  (Background)  │
                         └───────────────┘
```

## Features

- **Automatic Setup**: Database schema auto-imports on first run
- **Health Checks**: Built-in monitoring for all services
- **Security**: Non-root containers, restricted permissions, HTTPS support
- **Scalability**: Multi-stage builds, optimized for production workloads
- **Monitoring**: Centralized logging, health endpoints, cron job tracking
- **Backup Tools**: Automated backup scripts with retention policies

## Getting Started

Check out the [Quick Start Guide](quickstart) to get ITFlow running in under 5 minutes.

## Support

- [ITFlow Official Docs](https://docs.itflow.org)
- [ITFlow Forum](https://forum.itflow.org)
- [GitHub Issues](https://github.com/alivec0rpse/itflow-docker/issues)
