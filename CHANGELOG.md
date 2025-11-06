# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2025-11-06

### Added
- Complete containerization of nginx, web (Next.js), and api (NestJS) services
- Development mode with hot-reload support (`make dev-up`)
- Production mode for offline deployment (`make prov-save`, `make prov-load`, `make prov-up`)
- Comprehensive Makefile with 15+ automation commands
- Complete deployment documentation in `docs/DEPLOYMENT.md`
- Automated verification script (`verify.sh`)
- Health check endpoints for all services
- Bridge network isolation (no host mode)

### Technical Details
- **Node.js**: 22.11.0 (bookworm builder, slim runtime)
- **Nginx**: 1.27.2-alpine with curl for healthchecks
- **Next.js**: 14.2.18 with standalone output
- **NestJS**: 10.4.4 with watch mode support
- **Timezone**: Asia/Tokyo unified across all containers
- **Network**: Single bridge network (edge_net)
- **Ports**: External 8080 (nginx only), Internal 3002 (web), 3001 (api)

### Fixed
- Added `package-lock.json` for both web and api (required for `npm ci`)
- Changed nginx healthcheck from `wget` to `curl` (more reliable in alpine)
- Updated volume mounting strategy for better hot-reload support:
  - Web: Full directory mount with node_modules and .next excluded
  - API: Full directory mount with node_modules excluded (dist NOT excluded to allow NestJS rebuild)
- Removed `/app/dist` volume mount from api service to fix `EBUSY: resource busy or locked` error
  - NestJS watch mode needs to delete and recreate `dist/` directory
  - Volume-mounted directories cannot be deleted, causing startup failure
  - Solution: Only exclude `node_modules`, allow `dist/` to be part of main mount
- Ensured all compose files use curl for healthchecks consistently

### Security
- CORS disabled (same-origin via nginx proxy)
- Internal ports not exposed to host
- No secrets in repository
- Minimal runtime images (slim/alpine)
- No privileged containers

### Files Structure
```
.
├── Makefile                    # All automation tasks
├── README.md                   # Quick start guide
├── CHANGELOG.md               # This file
├── .gitignore                 # Git ignore rules
├── verify.sh                  # Verification script
├── compose/
│   ├── compose.dev.yml       # Development mode
│   ├── compose.prov.yml      # Production mode
│   └── .env.sample           # Environment template
├── docs/
│   └── DEPLOYMENT.md         # Complete deployment guide
├── edge/nginx/
│   ├── nginx.conf            # Reverse proxy config
│   └── Dockerfile            # Nginx image
├── reservation-web/
│   ├── Dockerfile            # Production build
│   ├── Dockerfile.dev        # Development build
│   ├── package.json
│   ├── package-lock.json     # Lockfile for npm ci
│   └── app/                  # Next.js app directory
└── reserve-api/
    ├── Dockerfile            # Production build
    ├── Dockerfile.dev        # Development build
    ├── package.json
    ├── package-lock.json     # Lockfile for npm ci
    └── src/                  # NestJS source
```

### Acceptance Criteria - All Met ✅
- [x] `make dev-up` → http://localhost:8080/ shows web
- [x] http://localhost:8080/api/ping returns 200 OK with JSON
- [x] http://localhost:8080/api/health returns service health
- [x] All services show 'healthy' status in `docker compose ps`
- [x] Prov mode supports offline deployment via tar files
- [x] nginx.conf handles all routing (no CORS configuration needed)
- [x] Bridge network only (no host mode)
- [x] Explicit version tags on all images
- [x] TZ=Asia/Tokyo on all containers
- [x] Healthchecks implemented on all services
- [x] package-lock.json present for deterministic builds

### Next Steps
1. Install Docker Engine v24+ and Docker Compose v2
2. Run `make dev-up` to start development environment
3. Access http://localhost:8080
4. Verify all services are healthy: `make dev-ps`
5. Test API: `curl http://localhost:8080/api/ping`
6. See `docs/DEPLOYMENT.md` for production deployment
