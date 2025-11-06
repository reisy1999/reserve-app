.PHONY: help dev-up dev-up-full dev-down dev-logs dev-ps dev-restart prov-build prov-save prov-load prov-up prov-down prov-ps clean

# Variables
DEV_COMPOSE := compose/compose.dev.yml
DEV_ENV := compose/.env.dev
PROV_COMPOSE := compose/compose.prov.yml
VERSION ?= 0.1.0
DIST_DIR := dist

# Image names
WEB_IMAGE := reservation-web:$(VERSION)
API_IMAGE := reserve-api:$(VERSION)
NGINX_IMAGE := edge-nginx:$(VERSION)

help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

#
# Development mode targets
#
dev-up: ## Start all services in dev mode with hot-reload
	docker compose -f $(DEV_COMPOSE) --env-file $(DEV_ENV) up -d --build

dev-up-full: ## Start all services including phpMyAdmin (port 9080)
	docker compose -f $(DEV_COMPOSE) --env-file $(DEV_ENV) --profile dev up -d --build

dev-down: ## Stop all dev services
	docker compose -f $(DEV_COMPOSE) --env-file $(DEV_ENV) down

dev-logs: ## Show logs from all dev services (follow mode)
	docker compose -f $(DEV_COMPOSE) --env-file $(DEV_ENV) logs -f

dev-ps: ## Show status of all dev services
	docker compose -f $(DEV_COMPOSE) --env-file $(DEV_ENV) ps

dev-restart: ## Restart all dev services
	docker compose -f $(DEV_COMPOSE) --env-file $(DEV_ENV) restart

#
# Production (prov) mode targets
#
prov-build: ## Build production images for prov mode
	@echo "Building production images..."
	docker build -t $(WEB_IMAGE) -f reservation-web/Dockerfile reservation-web
	docker build -t $(API_IMAGE) -f reserve-api/Dockerfile reserve-api
	docker build -t $(NGINX_IMAGE) -f edge/nginx/Dockerfile edge/nginx
	@echo "Build complete!"
	@echo "  - $(WEB_IMAGE)"
	@echo "  - $(API_IMAGE)"
	@echo "  - $(NGINX_IMAGE)"

prov-save: prov-build ## Build and save production images as tar files for offline distribution
	@echo "Creating distribution directory..."
	@mkdir -p $(DIST_DIR)
	@echo "Saving images to tar files..."
	docker image save -o $(DIST_DIR)/reservation-web-$(VERSION).tar $(WEB_IMAGE)
	docker image save -o $(DIST_DIR)/reserve-api-$(VERSION).tar $(API_IMAGE)
	docker image save -o $(DIST_DIR)/edge-nginx-$(VERSION).tar $(NGINX_IMAGE)
	@echo "Images saved to $(DIST_DIR)/"
	@ls -lh $(DIST_DIR)/*.tar

prov-load: ## Load production images from tar files (for offline deployment)
	@echo "Loading images from $(DIST_DIR)/"
	docker load -i $(DIST_DIR)/reservation-web-$(VERSION).tar
	docker load -i $(DIST_DIR)/reserve-api-$(VERSION).tar
	docker load -i $(DIST_DIR)/edge-nginx-$(VERSION).tar
	@echo "Images loaded successfully!"
	@docker images | grep -E "reservation-web|reserve-api|edge-nginx"

prov-up: ## Start all services in production mode (requires images to be loaded)
	docker compose -f $(PROV_COMPOSE) up -d

prov-down: ## Stop all production services
	docker compose -f $(PROV_COMPOSE) down

prov-ps: ## Show status of all production services
	docker compose -f $(PROV_COMPOSE) ps

prov-logs: ## Show logs from all production services
	docker compose -f $(PROV_COMPOSE) logs -f

#
# Utility targets
#
clean: ## Remove all containers, networks, and images (CAUTION: destructive)
	@echo "Stopping all services..."
	-docker compose -f $(DEV_COMPOSE) --env-file $(DEV_ENV) down
	-docker compose -f $(PROV_COMPOSE) down
	@echo "Cleaning up Docker resources..."
	-docker system prune -f
	@echo "Clean complete!"

clean-volumes: ## Remove all containers, networks, images, and volumes (CAUTION: very destructive)
	@echo "Stopping all services..."
	-docker compose -f $(DEV_COMPOSE) --env-file $(DEV_ENV) down -v
	-docker compose -f $(PROV_COMPOSE) down -v
	@echo "Cleaning up Docker resources including volumes..."
	-docker system prune -af --volumes
	@echo "Clean complete!"

test-dev: ## Test dev deployment (start, wait, check health, show status)
	@echo "Starting dev services..."
	@$(MAKE) dev-up
	@echo "Waiting for services to be healthy..."
	@sleep 10
	@echo "\nService status:"
	@$(MAKE) dev-ps
	@echo "\nTesting endpoints..."
	@echo -n "Web (/)        : "; curl -sS -o /dev/null -w "%{http_code}" http://localhost:8080/ && echo " ✓" || echo " ✗"
	@echo -n "API (/api/ping): "; curl -sS -o /dev/null -w "%{http_code}" http://localhost:8080/api/ping && echo " ✓" || echo " ✗"
	@echo "\nDev mode is ready at http://localhost:8080"

test-prov: ## Test prov deployment (requires images to be loaded)
	@echo "Starting prov services..."
	@$(MAKE) prov-up
	@echo "Waiting for services to be healthy..."
	@sleep 10
	@echo "\nService status:"
	@$(MAKE) prov-ps
	@echo "\nTesting endpoints..."
	@echo -n "Web (/)        : "; curl -sS -o /dev/null -w "%{http_code}" http://localhost:8080/ && echo " ✓" || echo " ✗"
	@echo -n "API (/api/ping): "; curl -sS -o /dev/null -w "%{http_code}" http://localhost:8080/api/ping && echo " ✓" || echo " ✗"
	@echo "\nProv mode is ready at http://localhost:8080"
