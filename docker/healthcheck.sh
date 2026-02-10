#!/bin/bash
# ITFlow Health Check Script
# Verifies the application is responding correctly

set -e

# Check if web server is responding
if ! curl -f -s http://localhost/ > /dev/null 2>&1; then
    echo "ERROR: Web server not responding"
    exit 1
fi

# Check if PHP is processing requests
if ! curl -s http://localhost/ | grep -q "ITFlow\|DOCTYPE\|html"; then
    echo "ERROR: PHP not processing requests properly"
    exit 1
fi

# Check if config.php exists
if [ ! -f "/var/www/html/config.php" ]; then
    echo "ERROR: config.php not found"
    exit 1
fi

echo "Health check passed"
exit 0
