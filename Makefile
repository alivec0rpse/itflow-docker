# ITFlow Docker - Makefile
# Convenient commands for managing the Docker environment

.PHONY: help build up down restart logs shell backup restore clean

# Default target
.DEFAULT_GOAL := help

# Variables
COMPOSE=docker-compose
SERVICE=itflow

help: ## Show this help message
	@echo "ITFlow Docker Management Commands"
	@echo "=================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Setup and Configuration
setup: ## Initial setup - copy .env.example to .env
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "✅ Created .env file. Please edit it with your configuration."; \
	else \
		echo "⚠️  .env file already exists"; \
	fi

# Docker Operations
build: ## Build Docker images
	$(COMPOSE) build

up: ## Start all services
	$(COMPOSE) up -d
	@echo "✅ ITFlow is starting..."
	@echo "Access at: http://localhost"

down: ## Stop all services
	$(COMPOSE) down

restart: ## Restart all services
	$(COMPOSE) restart

stop: ## Stop services without removing containers
	$(COMPOSE) stop

start: ## Start existing containers
	$(COMPOSE) start

# Logs and Monitoring
logs: ## Show logs (use 'make logs SERVICE=db' for specific service)
	$(COMPOSE) logs -f --tail=100 $(SERVICE)

logs-all: ## Show logs from all services
	$(COMPOSE) logs -f --tail=100

ps: ## Show running containers
	$(COMPOSE) ps

stats: ## Show container resource usage
	docker stats

# Shell Access
shell: ## Open shell in web container
	$(COMPOSE) exec $(SERVICE) bash

shell-db: ## Open MySQL shell
	$(COMPOSE) exec db mysql -u root -p

shell-cron: ## Open shell in cron container
	$(COMPOSE) exec itflow-cron bash

# Maintenance
backup: ## Create backup of database and uploads
	@bash backup.sh

restore: ## Restore from backup (use 'make restore DATE=20240209_143000')
	@if [ -z "$(DATE)" ]; then \
		echo "Please specify backup date: make restore DATE=20240209_143000"; \
		echo "Available backups:"; \
		ls -1 backups/ 2>/dev/null | grep -o '[0-9]\{8\}_[0-9]\{6\}' | sort -u || echo "No backups found"; \
	else \
		bash restore.sh $(DATE); \
	fi

update: ## Update ITFlow to latest version
	@echo "Updating ITFlow..."
	cd itflow-master && git pull origin master
	$(COMPOSE) build itflow itflow-cron
	$(COMPOSE) up -d
	@echo "✅ Update complete. Check Admin > System > Database Updates in web UI"

# Database Operations
db-backup: ## Backup database only
	@mkdir -p backups
	$(COMPOSE) exec -T db mysqldump -u root -p$$DB_ROOT_PASSWORD itflow > backups/db-backup-$$(date +%Y%m%d_%H%M%S).sql
	@echo "✅ Database backed up to backups/"

db-restore: ## Restore database from backup (use 'make db-restore FILE=backups/db-backup.sql')
	@if [ -z "$(FILE)" ]; then \
		echo "Please specify backup file: make db-restore FILE=backups/db-backup.sql"; \
	else \
		cat $(FILE) | $(COMPOSE) exec -T db mysql -u root -p$$DB_ROOT_PASSWORD itflow; \
		echo "✅ Database restored from $(FILE)"; \
	fi

db-shell: ## Open MySQL shell
	$(COMPOSE) exec db mysql -u root -p itflow

# Development
dev: ## Start in development mode with live logs
	$(COMPOSE) up

rebuild: ## Rebuild and restart all services
	$(COMPOSE) down
	$(COMPOSE) build --no-cache
	$(COMPOSE) up -d

# Tools
phpmyadmin: ## Start phpMyAdmin (http://localhost:8080)
	$(COMPOSE) --profile tools up -d phpmyadmin
	@echo "✅ phpMyAdmin started at http://localhost:8080"

nginx: ## Start Nginx reverse proxy
	$(COMPOSE) --profile nginx up -d nginx
	@echo "✅ Nginx reverse proxy started"

# Cleanup
clean: ## Remove stopped containers and unused volumes
	$(COMPOSE) down -v --remove-orphans
	docker system prune -f

clean-all: ## Remove all data including volumes (WARNING: DESTRUCTIVE)
	@echo "⚠️  This will delete ALL data including database!"
	@read -p "Are you sure? (yes/no): " confirm && [ "$$confirm" = "yes" ]
	$(COMPOSE) down -v
	rm -rf uploads/* logs/* config/* backups/*
	@echo "✅ All data removed"

# Health Checks
health: ## Check health of all services
	@echo "Service Health Status:"
	@$(COMPOSE) ps | grep -E "Up|healthy" || echo "Some services may be down"

test: ## Test database connection
	@echo "Testing database connection..."
	$(COMPOSE) exec -T itflow php -r "mysqli_connect('db', 'itflow', '$(shell grep DB_PASSWORD .env | cut -d= -f2)', 'itflow') or die('❌ Connection failed'); echo '✅ Database connection successful\n';"

# Information
info: ## Show configuration information
	@echo "=========================================="
	@echo "ITFlow Docker Environment"
	@echo "=========================================="
	@echo "Compose File: docker-compose.yml"
	@echo "Environment: .env"
	@echo ""
	@echo "Services:"
	@$(COMPOSE) ps
	@echo ""
	@echo "Volumes:"
	@docker volume ls | grep itflow

version: ## Show versions
	@echo "Docker: $$(docker --version)"
	@echo "Docker Compose: $$(docker-compose --version)"
	@echo "ITFlow: $$(cd itflow-master && git describe --tags 2>/dev/null || echo 'master')"

# Production
prod-up: ## Start in production mode (runs all checks)
	@if [ ! -f .env ]; then echo "❌ .env file not found. Run 'make setup' first"; exit 1; fi
	@grep -q "changeme" .env && echo "⚠️  Warning: Default passwords detected in .env" || true
	$(COMPOSE) up -d
	@echo "✅ Production environment started"
	@echo "Don't forget to:"
	@echo "  1. Complete web setup wizard"
	@echo "  2. Set ENABLE_SETUP=0 in .env"
	@echo "  3. Setup SSL certificates"
	@echo "  4. Configure firewall"
	@echo "  5. Setup automated backups"
