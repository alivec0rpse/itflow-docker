#!/bin/bash
# ITFlow Docker Production Deployment Checker
# Verifies that the environment is ready for production deployment

set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "=========================================="
echo "ITFlow Production Deployment Checker"
echo "=========================================="
echo ""

ERRORS=0
WARNINGS=0

# Function to check a requirement
check_required() {
    local description="$1"
    local test_command="$2"
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $description"
        return 0
    else
        echo -e "${RED}✗${NC} $description"
        ((ERRORS++))
        return 1
    fi
}

# Function to check a warning
check_warning() {
    local description="$1"
    local test_command="$2"
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $description"
        return 0
    else
        echo -e "${YELLOW}⚠${NC} $description"
        ((WARNINGS++))
        return 1
    fi
}

echo "Checking environment configuration..."
echo "--------------------------------------"

# Check if .env exists
if [ ! -f ".env" ]; then
    echo -e "${RED}✗${NC} .env file not found!"
    echo "  Run: cp .env.example .env"
    exit 1
fi

# Source the .env file
source .env

# Check database passwords
check_required "DB_PASSWORD is set" "[ -n '$DB_PASSWORD' ]"
check_required "DB_ROOT_PASSWORD is set" "[ -n '$DB_ROOT_PASSWORD' ]"

if [ "$DB_PASSWORD" = "changeme_secure_password_here" ]; then
    echo -e "${RED}✗${NC} DB_PASSWORD is still default value!"
    ((ERRORS++))
else
    check_warning "DB_PASSWORD is strong (20+ chars)" "[ ${#DB_PASSWORD} -ge 20 ]"
fi

if [ "$DB_ROOT_PASSWORD" = "changeme_root_password_here" ]; then
    echo -e "${RED}✗${NC} DB_ROOT_PASSWORD is still default value!"
    ((ERRORS++))
else
    check_warning "DB_ROOT_PASSWORD is strong (20+ chars)" "[ ${#DB_ROOT_PASSWORD} -ge 20 ]"
fi

# Check BASE_URL
check_required "BASE_URL is set" "[ -n '$BASE_URL' ]"
if [[ "$BASE_URL" == https://* ]]; then
    echo -e "${GREEN}✓${NC} BASE_URL uses HTTPS"
else
    echo -e "${YELLOW}⚠${NC} BASE_URL does not use HTTPS"
    ((WARNINGS++))
fi

# Check HTTPS_ONLY
if [ "$HTTPS_ONLY" = "true" ] || [ "$HTTPS_ONLY" = "TRUE" ]; then
    echo -e "${GREEN}✓${NC} HTTPS_ONLY is enabled"
else
    echo -e "${YELLOW}⚠${NC} HTTPS_ONLY is not enabled (recommended for production)"
    ((WARNINGS++))
fi

# Check ENABLE_SETUP
if [ "$ENABLE_SETUP" = "0" ]; then
    echo -e "${GREEN}✓${NC} ENABLE_SETUP is disabled (production mode)"
else
    echo -e "${YELLOW}⚠${NC} ENABLE_SETUP is enabled (disable after initial setup)"
    ((WARNINGS++))
fi

# Check INSTALLATION_ID
if [ -n "$INSTALLATION_ID" ]; then
    echo -e "${GREEN}✓${NC} INSTALLATION_ID is set"
else
    echo -e "${YELLOW}⚠${NC} INSTALLATION_ID not set (will be auto-generated)"
    ((WARNINGS++))
fi

echo ""
echo "Checking Docker environment..."
echo "--------------------------------------"

# Check Docker is running
check_required "Docker is running" "docker info"

# Check Docker Compose is available
check_required "Docker Compose is available" "docker-compose --version"

echo ""
echo "=========================================="
echo "Summary:"
echo "=========================================="

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Ready for production.${NC}"
    echo ""
    echo "Next steps:"
    echo "1. docker-compose build"
    echo "2. docker-compose up -d"
    echo "3. Visit $BASE_URL and complete setup wizard"
    echo "4. Set ENABLE_SETUP=0 and restart containers"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ $WARNINGS warning(s) found${NC}"
    echo "You can proceed, but review the warnings above."
    exit 0
else
    echo -e "${RED}✗ $ERRORS error(s) found${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠ $WARNINGS warning(s) found${NC}"
    fi
    echo "Fix the errors above before deploying to production."
    exit 1
fi
