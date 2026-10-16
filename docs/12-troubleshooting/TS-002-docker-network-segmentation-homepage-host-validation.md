Title

TS-0010 – Docker Network Segmentation and Homepage Host Validation
Summary

Symptoms:

status.polaris.home.arpa returned 502 Bad Gateway
homepage.polaris.home.arpa returned Host validation failed
Docker containers were healthy
DNS resolution was correct
NPM proxy hosts showed Online

Root Cause:

Nginx Proxy Manager was attached only to the infrastructure Docker network.
Uptime Kuma resided exclusively on the monitoring network.
Homepage required additional allowed host values when accessed through NPM.

Diagnosis Commands

docker network ls
docker network inspect infrastructure
docker network inspect monitoring
docker exec nginx-proxy-manager curl -I http://uptime-kuma:3001
docker exec nginx-proxy-manager curl -I http://homepage:3000
docker logs homepage --tail 50

Resolution

Attach NPM to monitoring network:

docker network connect monitoring nginx-proxy-manager

Modify compose:

services:
  nginx-proxy-manager:
    networks:
      - infrastructure
      - monitoring

networks:
  infrastructure:
    external: true
  monitoring:
    external: true

Homepage compose:

HOMEPAGE_ALLOWED_HOSTS: "homepage.polaris.home.arpa,homepage,homepage:3000,192.168.10.20:3000"

Validation

status.polaris.home.arpa
homepage.polaris.home.arpa
proxy.polaris.home.arpa
vault.polaris.home.arpa
git.polaris.home.arpa
firewall01.polaris.home.arpa

All operational.

Lessons Learned

Docker DNS is network scoped.
Reverse proxies spanning multiple service networks must participate in each published network.
Homepage Host Validation should remain enabled.
