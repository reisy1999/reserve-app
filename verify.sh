#!/bin/bash
# Verification script for containerized setup

set -e

echo "==================================="
echo "Verification Script"
echo "==================================="
echo ""

# Check required files exist
echo "✓ Checking required files..."

required_files=(
    "Makefile"
    "README.md"
    ".gitignore"
    "compose/compose.dev.yml"
    "compose/compose.prov.yml"
    "compose/.env.sample"
    "docs/DEPLOYMENT.md"
    "edge/nginx/nginx.conf"
    "edge/nginx/Dockerfile"
    "reservation-web/Dockerfile"
    "reservation-web/Dockerfile.dev"
    "reservation-web/package.json"
    "reservation-web/package-lock.json"
    "reservation-web/next.config.js"
    "reservation-web/tsconfig.json"
    "reservation-web/app/page.tsx"
    "reservation-web/app/layout.tsx"
    "reserve-api/Dockerfile"
    "reserve-api/Dockerfile.dev"
    "reserve-api/package.json"
    "reserve-api/package-lock.json"
    "reserve-api/tsconfig.json"
    "reserve-api/nest-cli.json"
    "reserve-api/src/main.ts"
    "reserve-api/src/app.module.ts"
    "reserve-api/src/app.controller.ts"
    "reserve-api/src/app.service.ts"
)

missing=0
for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "  ✗ Missing: $file"
        missing=$((missing + 1))
    fi
done

if [ $missing -eq 0 ]; then
    echo "  ✓ All ${#required_files[@]} required files exist"
else
    echo "  ✗ $missing files missing"
    exit 1
fi

echo ""
echo "✓ Checking file contents..."

# Check nginx.conf has required locations
if grep -q "location /" edge/nginx/nginx.conf && grep -q "location /api/" edge/nginx/nginx.conf; then
    echo "  ✓ nginx.conf has web and api proxy configurations"
else
    echo "  ✗ nginx.conf missing required proxy configurations"
    exit 1
fi

# Check Dockerfiles have required components
if grep -q "FROM node:22.11.0" reservation-web/Dockerfile && grep -q "HEALTHCHECK" reservation-web/Dockerfile; then
    echo "  ✓ Web Dockerfile has specific version tag and healthcheck"
else
    echo "  ✗ Web Dockerfile missing requirements"
    exit 1
fi

if grep -q "FROM node:22.11.0" reserve-api/Dockerfile && grep -q "HEALTHCHECK" reserve-api/Dockerfile; then
    echo "  ✓ API Dockerfile has specific version tag and healthcheck"
else
    echo "  ✗ API Dockerfile missing requirements"
    exit 1
fi

if grep -q "FROM nginx:1.27" edge/nginx/Dockerfile && grep -q "HEALTHCHECK" edge/nginx/Dockerfile && grep -q "curl" edge/nginx/Dockerfile; then
    echo "  ✓ Nginx Dockerfile has specific version tag, healthcheck, and curl"
else
    echo "  ✗ Nginx Dockerfile missing requirements"
    exit 1
fi

# Check lockfiles exist
if [ -f "reservation-web/package-lock.json" ] && [ -f "reserve-api/package-lock.json" ]; then
    echo "  ✓ Both package-lock.json files exist (for npm ci)"
else
    echo "  ✗ Missing package-lock.json files"
    exit 1
fi

# Check compose files
if grep -q "edge_net" compose/compose.dev.yml && grep -q "expose:" compose/compose.dev.yml; then
    echo "  ✓ Dev compose has bridge network and internal port exposure"
else
    echo "  ✗ Dev compose missing network configuration"
    exit 1
fi

if grep -q "image:" compose/compose.prov.yml && ! grep -q "build:" compose/compose.prov.yml; then
    echo "  ✓ Prov compose uses pre-built images (no build directive)"
else
    echo "  ✗ Prov compose should use images, not build"
    exit 1
fi

# Check API has required endpoints
if grep -q "getPing" reserve-api/src/app.controller.ts && grep -q "getHealth" reserve-api/src/app.controller.ts; then
    echo "  ✓ API has required /ping and /health endpoints"
else
    echo "  ✗ API missing required endpoints"
    exit 1
fi

# Check Makefile has required targets
required_targets=("dev-up" "dev-down" "prov-build" "prov-save" "prov-load" "prov-up")
for target in "${required_targets[@]}"; do
    if ! grep -q "^$target:" Makefile; then
        echo "  ✗ Makefile missing target: $target"
        exit 1
    fi
done
echo "  ✓ Makefile has all required targets"

echo ""
echo "==================================="
echo "✓ All verification checks passed!"
echo "==================================="
echo ""
echo "Next steps:"
echo "  1. Run 'make dev-up' to start development environment"
echo "  2. Access http://localhost:8080 for web interface"
echo "  3. Test http://localhost:8080/api/ping for API"
echo "  4. See docs/DEPLOYMENT.md for complete instructions"
echo ""
