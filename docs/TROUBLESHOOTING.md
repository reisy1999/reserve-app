# Troubleshooting Guide

Common issues and solutions for the containerized reserve application.

## API Container Unhealthy - DB Connection Failed

### Symptoms
- API container shows as "unhealthy" in `docker compose ps`
- Logs show: `ECONNREFUSED` or connection errors to `::1:3306` or `127.0.0.1:3306`
- NestJS cannot connect to MySQL database

### Cause
The reserve-api application uses `dotenv` to load configuration from `.env.dev` file. If `DB_HOST` is not set in this file, it defaults to `localhost`, which points to the container's own localhost (not the MySQL container).

### Solution
Ensure `reserve-api/.env.dev` contains the correct database host:

```bash
# reserve-api/.env.dev
DB_HOST=mysql          # <- Must be the Docker service name
DB_PORT=3306
DB_TYPE=mysql
DB_USERNAME=reserve_user
DB_PASSWORD=dev_reserve_password
DB_DATABASE=reserve_db
```

### Verification
1. Check API logs:
   ```bash
   docker compose -f compose/compose.dev.yml --env-file compose/.env.dev logs api
   ```

2. Verify environment variables inside container:
   ```bash
   docker compose -f compose/compose.dev.yml --env-file compose/.env.dev exec api env | grep DB_
   ```

3. Test MySQL connection from API container:
   ```bash
   docker compose -f compose/compose.dev.yml --env-file compose/.env.dev exec api sh -c "nc -zv mysql 3306"
   ```

## MySQL Container Won't Start

### Symptoms
- MySQL container exits immediately
- Error: `mysqld: Can't create directory '/var/lib/mysql/' (Errcode: 13 - Permission denied)`

### Solution
Remove the MySQL volume and restart:

```bash
make dev-down
docker volume rm reserve-app_mysql_data_dev
make dev-up
```

## Port Already in Use

### Symptoms
- Error: `Bind for 0.0.0.0:8080 failed: port is already allocated`

### Solution
1. Check what's using the port:
   ```bash
   sudo lsof -i :8080
   # or
   sudo netstat -tlnp | grep :8080
   ```

2. Stop the conflicting service or change the port in `compose/compose.dev.yml`:
   ```yaml
   nginx:
     ports:
       - "9090:8080"  # Changed from 8080:8080
   ```

## Web Container Build Fails

### Symptoms
- `reservation-web` submodule is empty
- Build error: `failed to solve with frontend dockerfile.v0`

### Solution
Initialize and update submodules:

```bash
git submodule update --init --recursive
```

If the submodule is private and authentication fails, you may need to configure Git credentials.

## Services Start But API Returns 404

### Cause
The API has a global prefix `/api` set in `app.config.ts`.

### Verification
Ensure you're accessing endpoints with the `/api/` prefix:

```bash
# Correct
curl http://localhost:8080/api/health

# Wrong (will return 404)
curl http://localhost:8080/health
```

## CORS Errors in Browser

### Cause
The nginx proxy should handle CORS, but if you're accessing services directly, CORS may fail.

### Solution
Always access through nginx (port 8080), not directly:

```bash
# Correct
http://localhost:8080/

# Wrong (bypasses nginx)
http://localhost:3002/
```

## Container Logs Show "EBUSY: resource busy or locked, rmdir '/app/dist'"

### Cause
NestJS watch mode needs to delete and recreate the `dist/` directory, but if it's mounted as a volume, it becomes locked.

### Solution
This issue has been fixed in the current configuration. The API service should NOT have `/app/dist` in its volume mounts:

```yaml
# Correct
volumes:
  - ../reserve-api:/app
  - /app/node_modules

# Wrong (will cause EBUSY)
volumes:
  - ../reserve-api:/app
  - /app/node_modules
  - /app/dist  # <- Remove this
```

## phpMyAdmin Shows "Connection Refused"

### Symptoms
- phpMyAdmin (port 9080) cannot connect to MySQL
- Error: `mysqli::real_connect(): (HY000/2002): Connection refused`

### Solution
1. Ensure MySQL is healthy:
   ```bash
   docker compose -f compose/compose.dev.yml --env-file compose/.env.dev ps mysql
   ```

2. Check phpMyAdmin configuration in compose file:
   ```yaml
   phpmyadmin:
     environment:
       PMA_HOST: mysql  # Must match MySQL service name
   ```

3. Restart with profile:
   ```bash
   docker compose -f compose/compose.dev.yml --env-file compose/.env.dev --profile dev up -d
   ```

## Complete Reset (Nuclear Option)

If all else fails, perform a complete cleanup:

```bash
# Stop all services
make dev-down

# Remove all containers, networks, volumes
make clean-volumes

# Remove all Docker resources (CAUTION)
docker system prune -af --volumes

# Restart from scratch
make dev-up
```

## Getting Help

1. Check service status:
   ```bash
   make dev-ps
   ```

2. View logs for specific service:
   ```bash
   docker compose -f compose/compose.dev.yml --env-file compose/.env.dev logs -f [service_name]
   ```

3. Inspect service configuration:
   ```bash
   docker compose -f compose/compose.dev.yml --env-file compose/.env.dev config
   ```

4. Check Docker daemon:
   ```bash
   docker info
   docker version
   ```

## Environment Variables Priority

The application loads environment variables in this order (last wins):

1. Hardcoded defaults in source code
2. `.env.dev` file in service directory (e.g., `reserve-api/.env.dev`)
3. `compose/.env.dev` file (loaded by Docker Compose)
4. `environment:` section in `compose/compose.dev.yml`
5. Shell environment variables (when running `docker compose` command)

**Important:** For Docker deployments, ensure both `reserve-api/.env.dev` and `compose/.env.dev` contain consistent values, especially for database connection parameters.
