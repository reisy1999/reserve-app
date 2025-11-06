# Deployment Guide

This document describes how to deploy the containerized reservation system in both **dev** (development) and **prov** (production/offline) modes.

## Overview

The system consists of three separate containers:

- **nginx**: Reverse proxy (port 8080 → web/api)
- **web**: Next.js frontend (internal port 3002)
- **api**: NestJS backend (internal port 3001)

All services communicate over a bridge network (`edge_net`). Only nginx is exposed to the host.

## Prerequisites

- Docker Engine v24+
- Docker Compose v2+
- Linux/WSL2 environment
- `make` utility
- `curl` for testing

## Architecture

```
┌─────────────────────────────────────┐
│         Host (localhost:8080)       │
└────────────────┬────────────────────┘
                 │
         ┌───────▼────────┐
         │     nginx      │
         │   (port 8080)  │
         └───┬────────┬───┘
             │        │
    ┌────────▼───┐  ┌▼──────────┐
    │    web     │  │    api    │
    │ (port 3002)│  │(port 3001)│
    └────────────┘  └───────────┘
         edge_net network
```

### Request Routing

- `http://localhost:8080/` → web:3002 (Next.js)
- `http://localhost:8080/api/` → api:3001 (NestJS)

CORS is disabled as all requests go through nginx (same-origin).

---

## Dev Mode (Development)

### Quick Start

```bash
# Start all services with hot-reload
make dev-up

# View logs
make dev-logs

# Check status
make dev-ps

# Stop services
make dev-down
```

### Features

- **Hot-reload**: Code changes are automatically reflected
- **Volume mounts**: Source code is mounted for live editing
- **Build on startup**: Images are built/rebuilt on `make dev-up`
- **Development dependencies**: Full npm packages installed

### Verification

After starting, verify all services are healthy:

```bash
# Check service status
docker compose -f compose/compose.dev.yml ps

# All services should show "healthy" status
```

Test the endpoints:

```bash
# Web frontend
curl http://localhost:8080/
# Expected: HTML page with "Reservation Web"

# API ping endpoint
curl http://localhost:8080/api/ping
# Expected: {"status":"ok","message":"pong","timestamp":"..."}

# API health endpoint
curl http://localhost:8080/api/health
# Expected: {"status":"healthy","service":"reserve-api",...}
```

### Troubleshooting

**Service not starting:**
```bash
# View specific service logs
docker compose -f compose/compose.dev.yml logs api
docker compose -f compose/compose.dev.yml logs web
docker compose -f compose/compose.dev.yml logs nginx
```

**Port already in use:**
```bash
# Check what's using port 8080
sudo lsof -i :8080

# Or change the port in compose/compose.dev.yml:
# nginx:
#   ports:
#     - "9090:8080"  # Use 9090 instead
```

**Services unhealthy:**
```bash
# Restart a specific service
docker compose -f compose/compose.dev.yml restart api

# Or restart all
make dev-restart
```

---

## Prov Mode (Production/Offline)

Prov mode is designed for **complete offline deployment** in isolated networks. Images are distributed as tar files.

### Build Workflow (On Connected Machine)

```bash
# 1. Build production images
make prov-build

# 2. Save images to tar files
make prov-save

# This creates:
# - dist/reservation-web-0.1.0.tar
# - dist/reserve-api-0.1.0.tar
# - dist/edge-nginx-0.1.0.tar
```

### Distribution Package

Prepare the following files for offline deployment:

```
deployment-package/
├── dist/
│   ├── reservation-web-0.1.0.tar
│   ├── reserve-api-0.1.0.tar
│   └── edge-nginx-0.1.0.tar
├── compose/
│   ├── compose.prov.yml
│   └── .env.sample
├── docs/
│   └── DEPLOYMENT.md (this file)
├── Makefile
└── README.md
```

### Deployment Workflow (On Offline Machine)

1. **Transfer the package** to the target machine (USB, secure transfer, etc.)

2. **Load images from tar files:**
   ```bash
   make prov-load
   # Or manually:
   docker load -i dist/reservation-web-0.1.0.tar
   docker load -i dist/reserve-api-0.1.0.tar
   docker load -i dist/edge-nginx-0.1.0.tar
   ```

3. **Verify images are loaded:**
   ```bash
   docker images | grep -E "reservation-web|reserve-api|edge-nginx"
   ```

4. **Configure environment (if needed):**
   ```bash
   cp compose/.env.sample compose/.env
   # Edit compose/.env with your configuration
   ```

5. **Start services:**
   ```bash
   make prov-up
   ```

6. **Verify deployment:**
   ```bash
   make test-prov
   ```

### Features

- **No network access required**: All images pre-built and loaded from tar
- **Production optimized**: Multi-stage builds, minimal image sizes
- **Auto-restart**: Services restart automatically on failure
- **No build step**: Uses pre-built images only

### Verification

```bash
# Check all services are running
docker compose -f compose/compose.prov.yml ps

# Test endpoints
curl http://localhost:8080/
curl http://localhost:8080/api/ping
curl http://localhost:8080/api/health
```

Expected output:
- All services should be in "healthy" state
- Web endpoint returns 200 OK
- API endpoints return JSON responses

### Configuration

Environment variables can be set in:
1. `compose/.env` file (recommended)
2. Direct modification of `compose/compose.prov.yml`

Example `.env`:
```bash
NODE_ENV=production
TZ=Asia/Tokyo
# Add database configuration, API keys, etc.
```

### Stopping Services

```bash
# Stop all services (keeps data)
make prov-down

# Stop and remove everything
docker compose -f compose/compose.prov.yml down -v
```

---

## Recovery Procedures

### Service Failure Recovery

```bash
# Check which service failed
make prov-ps  # or make dev-ps

# View logs
docker compose -f compose/compose.prov.yml logs [service-name]

# Restart specific service
docker compose -f compose/compose.prov.yml restart [service-name]
```

### Complete System Reset

```bash
# Dev mode
make dev-down
make clean
make dev-up

# Prov mode
make prov-down
docker system prune -f
make prov-load  # Re-load images
make prov-up
```

### Image Corruption Recovery

If images are corrupted in prov mode:

```bash
# Remove corrupted images
docker rmi reservation-web:0.1.0 reserve-api:0.1.0 edge-nginx:0.1.0

# Re-load from tar files
make prov-load

# Restart services
make prov-up
```

---

## Network Configuration

### Default Ports

- **External**: 8080 (nginx)
- **Internal**: 3002 (web), 3001 (api)

### Changing External Port

Edit `compose/compose.dev.yml` or `compose/compose.prov.yml`:

```yaml
services:
  nginx:
    ports:
      - "9090:8080"  # Change 9090 to desired port
```

Then restart:
```bash
make dev-down && make dev-up
# or
make prov-down && make prov-up
```

### Network Mode

The system uses **bridge network only**. Host network mode is **not supported** per security requirements.

---

## Health Checks

All services implement health checks:

- **nginx**: `wget http://localhost:8080/`
- **web**: `curl http://localhost:3002/`
- **api**: `curl http://localhost:3001/health`

Health check parameters:
- Interval: 10s
- Timeout: 3s
- Start period: 5-30s
- Retries: 3

---

## Version Management

To deploy a different version:

```bash
# Build with specific version
make prov-build VERSION=0.2.0

# Save with specific version
make prov-save VERSION=0.2.0

# Update compose/compose.prov.yml to reference new version:
# image: reservation-web:0.2.0
```

---

## Security Considerations

1. **No secrets in repository**: Use environment variables or Docker secrets
2. **CORS disabled**: All traffic routes through nginx
3. **Internal ports not exposed**: Only nginx port 8080 is public
4. **Bridge network isolation**: Services communicate only within defined network
5. **Production images**: Minimal attack surface with slim base images

---

## Logs

View logs in real-time:

```bash
# All services
make dev-logs  # or make prov-logs

# Specific service
docker compose -f compose/compose.dev.yml logs -f web
docker compose -f compose/compose.dev.yml logs -f api
docker compose -f compose/compose.dev.yml logs -f nginx
```

Logs are output to stdout/stderr and collected by Docker's logging driver.

---

## Quick Reference

### Development Commands

| Command | Description |
|---------|-------------|
| `make dev-up` | Start dev environment |
| `make dev-down` | Stop dev environment |
| `make dev-logs` | View logs |
| `make dev-ps` | Show service status |
| `make dev-restart` | Restart all services |
| `make test-dev` | Test dev deployment |

### Production Commands

| Command | Description |
|---------|-------------|
| `make prov-build` | Build production images |
| `make prov-save` | Save images to tar |
| `make prov-load` | Load images from tar |
| `make prov-up` | Start production services |
| `make prov-down` | Stop production services |
| `make prov-ps` | Show service status |
| `make test-prov` | Test prov deployment |

### Utility Commands

| Command | Description |
|---------|-------------|
| `make help` | Show all available commands |
| `make clean` | Remove all containers and images |

---

## Support

For issues or questions:
1. Check service logs: `make dev-logs` or `make prov-logs`
2. Verify service health: `make dev-ps` or `make prov-ps`
3. Review this documentation
4. Check Docker and system resources: `docker system df`

---

## Appendix: File Structure

```
.
├── Makefile                          # All automation tasks
├── compose/
│   ├── compose.dev.yml              # Dev mode compose file
│   ├── compose.prov.yml             # Prov mode compose file
│   └── .env.sample                  # Environment template
├── docs/
│   └── DEPLOYMENT.md                # This file
├── edge/
│   └── nginx/
│       ├── Dockerfile               # Nginx production image
│       └── nginx.conf               # Nginx configuration
├── reservation-web/
│   ├── Dockerfile                   # Web production image
│   ├── Dockerfile.dev               # Web dev image
│   ├── package.json
│   ├── next.config.js
│   └── app/                         # Next.js app directory
├── reserve-api/
│   ├── Dockerfile                   # API production image
│   ├── Dockerfile.dev               # API dev image
│   ├── package.json
│   └── src/                         # NestJS source code
└── dist/                            # Generated tar files (gitignored)
```
