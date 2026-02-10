#!/bin/bash
# ITFlow Cron Service Health Check
# Verifies cron daemon is running and jobs are scheduled

set -e

# Check if cron daemon is running
if ! pgrep -x cron > /dev/null; then
    echo "ERROR: Cron daemon not running"
    exit 1
fi

# Check if cron jobs file exists
if [ ! -f "/etc/cron.d/itflow-cron" ]; then
    echo "ERROR: Cron jobs file not found"
    exit 1
fi

# Check if cron log exists (proves jobs are attempting to run)
if [ ! -f "/var/log/cron.log" ]; then
    echo "WARNING: Cron log not created yet"
    # Don't fail - it's created on first job execution
fi

echo "Cron health check passed"
exit 0
