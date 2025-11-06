# Reserve Application

Containerized reservation system with separate nginx, web (Next.js), and api (NestJS) services.

## Quick Start

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

```bash
# Build and save images for offline distribution
make prov-save

# On target machine: load images
make prov-load

# Start production services
make prov-up
```

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
