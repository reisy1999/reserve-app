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

- **nginx**: Reverse proxy (port 8080)
- **web**: Next.js frontend (internal port 3002)
- **api**: NestJS backend (internal port 3001)

All services communicate over a private bridge network. Only nginx is exposed externally.

## Available Commands

Run `make help` to see all available commands:

```bash
make help
```

### Quick Reference

- `make dev-up` - Start development environment
- `make dev-down` - Stop development environment
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
