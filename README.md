# Reserve Application

Containerized reservation system with separate nginx, web (Next.js), and api (NestJS) services.

## Quick Start

### Initial Setup

**IMPORTANT**: Before starting, create environment configuration files:

```bash
# Development environment (already exists)
# Review and modify if needed: compose/.env.dev

# Production environment (create from template)
cp compose/.env.example compose/.env
# Edit compose/.env with production values (secrets, passwords, etc.)
```

### Development Mode

```bash
# Start all services with hot-reload
make dev-up

# View logs
make dev-logs

# Access the application
open http://localhost:8080
```

### Production Mode (Offline Deployment)

**Build Environment** (with internet access):

```bash
# 1. Create production environment file
cp compose/.env.example compose/.env
# Edit compose/.env with production secrets

# 2. Build and save images for offline distribution
# IMPORTANT: NEXT_PUBLIC_* variables are embedded at build time
make prov-save

# 3. Transfer to target machine:
#    - dist/*.tar (Docker images)
#    - compose/.env (environment configuration)
#    - compose/compose.prov.yml (compose configuration)
#    - Makefile (optional, for convenience)
```

**Target Machine** (offline environment):

```bash
# 1. Ensure compose/.env exists in the same location

# 2. Load images
make prov-load

# 3. Start production services
make prov-up

# 4. Verify deployment
make prov-ps
```

## Environment Variables

All environment variables are managed in a **single source of truth**:

- `compose/.env.example` - Template with all available variables
- `compose/.env.dev` - Development configuration (committed to repo)
- `compose/.env` - Production configuration (**DO NOT commit**)

### Key Variables

**Database**:
- `MYSQL_*` - MySQL server configuration
- `DB_*` - API database connection settings

**Security**:
- `JWT_SECRET`, `JWT_REFRESH_SECRET` - JWT token signing keys
- `ADMIN_TOKEN` - Admin API authentication token
- `SECURITY_PIN_PEPPER` - Additional security for PIN hashing

**Next.js Public Variables** (embedded at build time):
- `NEXT_PUBLIC_API_BASE_URL` - API endpoint for frontend
- `NEXT_PUBLIC_ADMIN_TOKEN` - **Must match `ADMIN_TOKEN`**

⚠️ **IMPORTANT**:
- `ADMIN_TOKEN` and `NEXT_PUBLIC_ADMIN_TOKEN` must have identical values
- `NEXT_PUBLIC_*` variables are embedded into the Next.js bundle at build time
- Changing `NEXT_PUBLIC_*` requires rebuilding the web image

### Environment File Structure

Docker Compose loads variables in this order (higher priority first):
1. `--env-file` specified in command
2. `environment:` section in compose.yml
3. Shell environment variables

All `docker compose` commands **must** include `--env-file` (automated in Makefile).

## Documentation

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for complete deployment instructions, troubleshooting, and recovery procedures.

## Architecture

- **nginx**: Reverse proxy (port 8080) - Routes / → web, /api/ → api
- **web**: Next.js frontend (internal port 3002)
- **api**: NestJS backend (internal port 3000)
- **mysql**: MySQL 8.0 database (internal port 3306)
- **phpmyadmin**: Database management tool (port 9080, optional)

All services communicate over a private bridge network (`edge_net`). Only nginx and phpMyAdmin are exposed externally.

## Available Commands

Run `make help` to see all available commands:

```bash
make help
```

### Quick Reference

- `make dev-up` - Start development environment (mysql + api + web + nginx)
- `make dev-up-full` - Start with phpMyAdmin included (http://localhost:9080)
- `make dev-down` - Stop development environment
- `make dev-logs` - View logs from all services
- `make dev-ps` - Show service status
- `make prov-build` - Build production images
- `make prov-save` - Save images for offline deployment
- `make prov-up` - Start production services
- `make test-dev` - Test development deployment
- `make test-prov` - Test production deployment

## Requirements

- Docker Engine v24+
- Docker Compose v2+
- Linux/WSL2
- Make

## License

Private - All Rights Reserved
