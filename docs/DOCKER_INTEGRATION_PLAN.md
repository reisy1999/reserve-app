# Docker Configuration Integration Plan

## 📊 Current State Analysis

### Existing reserve-api Configuration
```yaml
Services:
  - mysql: MySQL 8.0 (port 3306, with init scripts)
  - api: NestJS (external 3001 → internal 3000)
  - phpmyadmin: DB管理ツール (port 8080)
Network: reserve-api-network
Dockerfiles: Dockerfile.dev (node:20-alpine), Dockerfile (node:20.19.3-alpine multi-stage)
```

### Created Infrastructure Configuration
```yaml
Services:
  - nginx: Reverse proxy (port 8080, proxies / → web:3002, /api/ → api:3001)
  - web: Next.js placeholder (port 3002, DUMMY)
  - api: NestJS placeholder (port 3001, DUMMY)
Network: edge_net
Missing: MySQL database
```

## 🚨 Integration Conflicts

| Issue | Existing | Created | Impact |
|-------|----------|---------|--------|
| API Internal Port | 3000 | 3001 | nginx.conf needs adjustment |
| phpMyAdmin Port | 8080 | - | Conflicts with nginx:8080 |
| MySQL | ✅ Exists | ❌ Missing | Database required |
| Network Name | reserve-api-network | edge_net | Need unified network |
| Node Version | node:20 | node:22 | Version mismatch |
| CORS Config | localhost:5000 | Disabled (nginx) | nginx same-origin strategy |

## 🎯 Integration Strategy

### Option A: **Unified Monorepo Approach** (RECOMMENDED)

Merge all services into single compose file with nginx as gateway.

**Architecture:**
```
┌─────────────────────────────────────────┐
│    Host: localhost:8080 (nginx)         │
└────────────────┬────────────────────────┘
                 │
         ┌───────▼────────┐
         │     nginx      │
         │   port 8080    │
         └───┬────────┬───┘
             │        │
    ┌────────▼───┐  ┌▼──────────┐       ┌──────────┐
    │    web     │  │    api    │───────│  mysql   │
    │ port 3002  │  │ port 3000 │       │ port 3306│
    └────────────┘  └───────────┘       └──────────┘
              edge_net (unified)

    Optional:
    ┌──────────────┐
    │  phpmyadmin  │
    │  port 9080   │ (changed from 8080)
    └──────────────┘
```

**Changes Required:**

1. **Merge MySQL** into compose/compose.dev.yml
2. **Adjust nginx.conf**: `/api/` → `http://api:3000/` (not 3001)
3. **Use existing Dockerfiles** from reserve-api
4. **Change phpMyAdmin port**: 8080 → 9080
5. **Unified network**: edge_net
6. **Environment variables**: Add DB_*, JWT_*, ADMIN_TOKEN to api service
7. **Remove CORS origins**: nginx handles same-origin

### Option B: Keep Separate Compose Files

Keep reserve-api/docker-compose.dev.yml separate, use external network.

**Pros:** Less disruption to existing setup
**Cons:** More complex, multiple compose commands, network configuration overhead

## ✅ Recommended Implementation (Option A)

### Step 1: Update compose/compose.dev.yml

```yaml
name: edge-dev

services:
  mysql:
    image: mysql:8.0
    container_name: reserve-mysql-dev
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:-root_password}
      MYSQL_DATABASE: ${MYSQL_DATABASE:-reserve_db}
      MYSQL_USER: ${MYSQL_USER:-reserve_user}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD:-reserve_password}
      TZ: Asia/Tokyo
    expose:
      - "3306"
    volumes:
      - mysql_data_dev:/var/lib/mysql
      - ../reserve-api/docker/mysql/init:/docker-entrypoint-initdb.d
    command:
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
      - --default-authentication-plugin=mysql_native_password
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD:-root_password}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - edge_net

  api:
    build:
      context: ../reserve-api
      dockerfile: Dockerfile.dev
    expose:
      - "3000"  # ← Changed from 3001
    environment:
      - TZ=Asia/Tokyo
      - NODE_ENV=development
      - PORT=3000
      # Database
      - DB_TYPE=mysql
      - DB_HOST=mysql
      - DB_PORT=3306
      - DB_USERNAME=${MYSQL_USER:-reserve_user}
      - DB_PASSWORD=${MYSQL_PASSWORD:-reserve_password}
      - DB_DATABASE=${MYSQL_DATABASE:-reserve_db}
      # JWT
      - JWT_SECRET=${JWT_SECRET:-dev-jwt-secret-change-in-production}
      - JWT_REFRESH_SECRET=${JWT_REFRESH_SECRET:-dev-jwt-refresh-secret}
      - JWT_EXPIRES_IN=${JWT_EXPIRES_IN:-15m}
      - JWT_REFRESH_EXPIRES_IN=${JWT_REFRESH_EXPIRES_IN:-7d}
      # Admin
      - ADMIN_TOKEN=${ADMIN_TOKEN:-dev-admin-token-change-in-production}
      # CORS not needed (nginx same-origin)
    volumes:
      - ../reserve-api:/app
      - /app/node_modules
    depends_on:
      mysql:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-fsS", "http://localhost:3000/health"]
      interval: 10s
      timeout: 3s
      start_period: 30s
      retries: 3
    networks:
      - edge_net

  web:
    build:
      context: ../reservation-web
      dockerfile: Dockerfile.dev
    expose:
      - "3002"
    environment:
      - TZ=Asia/Tokyo
      - NODE_ENV=development
    volumes:
      - ../reservation-web:/app
      - /app/node_modules
      - /app/.next
    depends_on:
      api:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-fsS", "http://localhost:3002/"]
      interval: 10s
      timeout: 3s
      start_period: 30s
      retries: 3
    networks:
      - edge_net

  nginx:
    build:
      context: ../edge/nginx
      dockerfile: Dockerfile
    ports:
      - "8080:8080"
    environment:
      - TZ=Asia/Tokyo
    healthcheck:
      test: ["CMD", "curl", "-fsS", "http://localhost:8080/", "-o", "/dev/null"]
      interval: 10s
      timeout: 3s
      start_period: 5s
      retries: 3
    depends_on:
      web:
        condition: service_healthy
      api:
        condition: service_healthy
    networks:
      - edge_net

  # Optional: Database management tool
  phpmyadmin:
    image: phpmyadmin:latest
    container_name: reserve-phpmyadmin-dev
    restart: unless-stopped
    environment:
      PMA_HOST: mysql
      PMA_PORT: 3306
      PMA_USER: root
      PMA_PASSWORD: ${MYSQL_ROOT_PASSWORD:-root_password}
      UPLOAD_LIMIT: 50M
    ports:
      - "9080:80"  # ← Changed from 8080 to avoid conflict
    depends_on:
      mysql:
        condition: service_healthy
    networks:
      - edge_net
    profiles:
      - dev  # Start with: docker compose --profile dev up

volumes:
  mysql_data_dev:
    driver: local

networks:
  edge_net:
    driver: bridge
```

### Step 2: Update edge/nginx/nginx.conf

```nginx
# Change line 44 (approximately)
location /api/ {
  proxy_pass         http://api:3000/;  # ← Changed from 3001 to 3000
  proxy_http_version 1.1;
  proxy_set_header   Host $host;
  proxy_set_header   X-Real-IP $remote_addr;
  proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header   X-Forwarded-Proto $scheme;

  proxy_buffering off;
  proxy_read_timeout 300s;
  proxy_connect_timeout 75s;
}
```

### Step 3: Add Environment File

Create `compose/.env.dev`:
```bash
# MySQL Configuration
MYSQL_ROOT_PASSWORD=dev_root_password
MYSQL_DATABASE=reserve_db
MYSQL_USER=reserve_user
MYSQL_PASSWORD=dev_reserve_password

# JWT Configuration
JWT_SECRET=dev-jwt-secret-change-in-production-abc123xyz
JWT_REFRESH_SECRET=dev-jwt-refresh-secret-change-in-production-xyz789
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d

# Admin Token
ADMIN_TOKEN=dev-admin-token-change-in-production-admin123
```

### Step 4: Update Makefile

```makefile
# Add env file loading
dev-up: ## Start all services in dev mode with hot-reload
	docker compose -f $(DEV_COMPOSE) --env-file compose/.env.dev up -d --build

# Add phpmyadmin option
dev-up-full: ## Start all services including phpMyAdmin
	docker compose -f $(DEV_COMPOSE) --env-file compose/.env.dev --profile dev up -d --build
```

## 🧪 Verification Steps

### 1. Database Initialization
```bash
make dev-up
# MySQL should initialize with tables from reserve-api/docker/mysql/init/01-create-tables.sql
```

### 2. API Connectivity
```bash
# Health check
curl http://localhost:8080/api/health

# Should return: {"status":"healthy","service":"reserve-api",...}
```

### 3. Web Access
```bash
curl http://localhost:8080/
# Should return web homepage
```

### 4. Database Access (optional)
```bash
make dev-up-full  # Starts with phpMyAdmin
# Access http://localhost:9080
# Login: root / dev_root_password
```

## 🔄 Migration Path

### Phase 1: Preparation (No Breaking Changes)
1. Add .env.dev file
2. Update documentation

### Phase 2: Integration (Breaking Changes)
1. Update compose/compose.dev.yml (add mysql)
2. Update nginx.conf (port 3000)
3. Update Makefile (env file)
4. Test dev-up

### Phase 3: Production Setup
1. Update compose/compose.prov.yml
2. Build production images
3. Test offline deployment

## 📝 Notes

- **reservation-web**: Submodule not yet cloned, may need Dockerfile creation
- **Version mismatch**: reserve-api uses node:20, can upgrade to node:22 if needed
- **CORS**: No longer needed as nginx provides same-origin
- **Database migrations**: Use reserve-api/docker/mysql/init scripts
- **Secrets**: Use .env.dev for development, Docker secrets for production

## ⚠️ Breaking Changes

1. API internal port changes from 3001 → 3000
2. Network name changes from reserve-api-network → edge_net
3. phpMyAdmin port changes from 8080 → 9080
4. Requires MySQL container (new dependency)
5. Environment variables must be configured

## ✅ Benefits

1. ✅ Single command startup: `make dev-up`
2. ✅ Unified network topology
3. ✅ nginx gateway for all services
4. ✅ Hot-reload for both web and api
5. ✅ Database management via phpMyAdmin (optional)
6. ✅ Production-ready docker images
7. ✅ Consistent timezone (Asia/Tokyo)
8. ✅ Health checks on all services

## 🎯 Next Actions

1. Review and approve this plan
2. Implement Step 1-4 changes
3. Test with `make dev-up`
4. Verify all endpoints
5. Update documentation
