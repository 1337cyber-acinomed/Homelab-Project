Purpose

Recover Docker services after network loss or compose recreation.

Recovery Procedure

Verify Docker networks
docker network ls
Inspect memberships
docker network inspect infrastructure
docker network inspect monitoring
Reconnect temporarily
docker network connect monitoring nginx-proxy-manager
Update compose
networks:
  - infrastructure
  - monitoring
Rebuild
docker compose down
docker compose up -d
Validate
docker exec nginx-proxy-manager curl -I http://uptime-kuma:3001
docker exec nginx-proxy-manager curl -I http://homepage:3000

Recovery Complete Criteria

Proxy reaches all services.
DNS resolves correctly.
HTTPS services load normally.
No Homepage host validation errors.
