---
layout: default
title: Troubleshooting
---

# Troubleshooting

Common issues and solutions.

## Database Connection Failed

**Symptoms**: "Could not connect to database" error

**Solutions**:

1. Check database is running:
```bash
docker-compose ps db
# Should show "Up" and "(healthy)"
```

2. Check database logs:
```bash
docker-compose logs db
```

3. Test connection:
```bash
docker-compose exec db mysql -u root -p
# Enter DB_ROOT_PASSWORD when prompted
```

4. Restart services:
```bash
docker-compose restart
```

5. Check `config.php`:
```bash
docker-compose exec itflow cat /var/www/html/config.php
```

## 500 Internal Server Error

**Symptoms**: Blank page or "500 Internal Server Error"

**Solutions**:

1. Check Apache error logs:
```bash
docker-compose logs itflow
# Or on host:
tail -f logs/error.log
```

2. Check PHP errors:
```bash
docker-compose exec itflow tail /var/log/apache2/error.log
```

3. Common causes:
   - **Missing database tables**: Database not initialized
   - **Permission errors**: See "Permission Issues" below
   - **PHP memory limit**: Check `PHP_MEMORY_LIMIT` in `.env`

4. Verify database schema:
```bash
docker-compose exec db mysql -u root -p itflow -e "SHOW TABLES;"
# Should show 137 tables
```

## Permission Issues

**Symptoms**: "Permission denied" errors in logs

**Solutions**:

Fix upload directory permissions:
```bash
docker-compose exec itflow chown -R www-data:www-data /var/www/html/uploads
docker-compose exec itflow chmod -R 775 /var/www/html/uploads
```

Fix log directory:
```bash
docker-compose exec itflow chown -R www-data:www-data /var/log/apache2
```

On host (if bind mounts have wrong owner):
```bash
sudo chown -R 33:33 uploads/ logs/ config/
# 33:33 is www-data UID:GID
```

## Port Already in Use

**Symptoms**: "port is already allocated" error

**Solutions**:

1. Find what's using the port:
```bash
# Windows
netstat -ano | findstr :80

# Linux
netstat -tulpn | grep :80
```

2. Stop conflicting service:
```bash
# Windows (IIS)
iisreset /stop

# Linux (Apache)
systemctl stop apache2
```

3. Or change port in `.env`:
```bash
WEB_PORT=8080
```

Then restart:
```bash
docker-compose down
docker-compose up -d
```

## Setup Wizard Still Shows After Setup

**Problem**: Setup wizard accessible after completing setup

**Solution**:

1. Edit `.env`:
```bash
ENABLE_SETUP=0
```

2. Restart ITFlow:
```bash
docker-compose restart itflow
```

3. Verify:
```bash
curl -I http://localhost/setup/
# Should return 403 Forbidden
```

## Cron Jobs Not Running

**Symptoms**: Email not sending, domains not updating, etc.

**Solutions**:

1. Check cron container is running:
```bash
docker-compose ps itflow-cron
# Should show "Up"
```

2. Check cron logs:
```bash
docker-compose exec itflow-cron tail -f /var/log/cron.log
```

3. Verify cron is loaded:
```bash
docker-compose exec itflow-cron crontab -l
```

4. Manual cron run (test):
```bash
docker-compose exec itflow-cron /var/www/html/cron/cron.php
```

5. Restart cron container:
```bash
docker-compose restart itflow-cron
```

## Email Not Sending

**Solutions**:

1. Check mail queue:
```bash
# Via web interface:
Admin > Mail Queue
```

2. Check cron logs for errors:
```bash
docker-compose exec itflow-cron grep -i mail /var/log/cron.log
```

3. Test SMTP settings:
```bash
# Via web interface:
Admin > Settings > Mail > Test Email
```

4. Check SMTP credentials in `.env`:
```bash
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_ENCRYPTION=tls
```

## File Upload Fails

**Symptoms**: "File upload failed" or "File too large"

**Solutions**:

1. Check PHP upload limits:
```bash
docker-compose exec itflow php -i | grep upload_max
# Should show 512M
```

2. Check POST size limit:
```bash
docker-compose exec itflow php -i | grep post_max
# Should show 512M
```

3. If limits are wrong, edit `docker/php/php-prod.ini`:
```ini
upload_max_filesize = 512M
post_max_size = 512M
```

4. Rebuild and restart:
```bash
docker-compose build itflow
docker-compose restart itflow
```

## SSL Certificate Issues

**Problem**: "Your connection is not private" or certificate errors

**Solutions**:

1. Check certificate files exist:
```bash
ls -la docker/nginx/ssl/
# Should have cert.pem and key.pem
```

2. Verify certificate is valid:
```bash
openssl x509 -in docker/nginx/ssl/cert.pem -noout -dates
```

3. Check Nginx logs:
```bash
docker-compose logs nginx
```

4. Renew Let's Encrypt certificate:
```bash
certbot renew
docker-compose restart nginx
```

## Docker Build Fails

**Solutions**:

1. Clean Docker cache:
```bash
docker-compose build --no-cache
```

2. Remove old images:
```bash
docker system prune -a
```

3. Check disk space:
```bash
df -h
```

4. Check Docker logs:
```bash
docker system df
docker system info
```

## Container Constantly Restarting

**Solutions**:

1. Check container logs:
```bash
docker-compose logs itflow
```

2. Check exit code:
```bash
docker-compose ps
# Look at STATUS column
```

3. Start in foreground (debug):
```bash
docker-compose up itflow
# Watch output for errors
```

4. Check entrypoint script:
```bash
docker-compose exec itflow cat /usr/local/bin/entrypoint.sh
```

## Health Check Failing

**Problem**: Container shows "(unhealthy)" status

**Solutions**:

1. Check health endpoint:
```bash
curl -v http://localhost/
```

2. Check Apache is running:
```bash
docker-compose exec itflow ps aux | grep apache
```

3. Check health check logs:
```bash
docker inspect --format='{{json .State.Health}}' itflow-docker-itflow-1
```

4. Increase health check timeout in `docker-compose.yml`:
```yaml
healthcheck:
  timeout: 20s  # Increase from 10s
  start_period: 60s  # Increase from 40s
```

## Database Initialization Failed

**Problem**: Database tables not created on first run

**Solutions**:

1. Check if `db.sql` exists:
```bash
ls -la itflow-master/db.sql
```

2. Check entrypoint logs:
```bash
docker-compose logs itflow | grep "Database is empty"
```

3. Manual database import:
```bash
docker-compose exec -T db mysql -u root -p itflow < itflow-master/db.sql
```

4. Verify tables created:
```bash
docker-compose exec db mysql -u root -p itflow -e "SHOW TABLES;"
```

## Performance Issues

**Symptoms**: Slow page loads, timeout errors

**Solutions**:

1. Check container resources:
```bash
docker stats
```

2. Increase PHP memory:
```ini
# Edit docker/php/php-prod.ini
memory_limit = 1024M
```

3. Increase MySQL buffer pool:
```ini
# Edit docker/mysql/mysql.cnf
innodb_buffer_pool_size = 2G
```

4. Enable OPcache (should be enabled by default):
```bash
docker-compose exec itflow php -i | grep opcache.enable
```

5. Restart after changes:
```bash
docker-compose restart
```

## Can't Access Admin Panel

**Solutions**:

1. Check user role in database:
```bash
docker-compose exec db mysql -u root -p itflow
```

```sql
SELECT user_email, user_role FROM users;
UPDATE users SET user_role=3 WHERE user_email='admin@example.com';
```

2. Reset admin password:
```sql
UPDATE users 
SET user_password='$2y$10$...' -- Generate with password_hash() 
WHERE user_email='admin@example.com';
```

## Backup Script Fails

**Solutions**:

1. Check permissions:
```bash
chmod +x backup.sh
```

2. Check Docker is accessible:
```bash
docker-compose ps
```

3. Check disk space:
```bash
df -h
```

4. Run with verbose output:
```bash
bash -x backup.sh
```

## Still Having Issues?

1. **Check logs**: Most issues show up in logs
```bash
docker-compose logs -f
```

2. **Search issues**: Check [GitHub Issues](https://github.com/alivec0rpse/itflow-docker/issues)

3. **ITFlow Forum**: [forum.itflow.org](https://forum.itflow.org)

4. **Create issue**: [Open new issue](https://github.com/alivec0rpse/itflow-docker/issues/new)

Include in your issue:
- Docker version: `docker --version`
- Compose version: `docker-compose --version`
- OS: `uname -a` (Linux) or `systeminfo` (Windows)
- Logs: `docker-compose logs`
- Steps to reproduce
