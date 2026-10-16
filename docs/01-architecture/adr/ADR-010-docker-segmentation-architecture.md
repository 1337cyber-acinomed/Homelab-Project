Status

Accepted

Context

Project Polaris requires logical separation between Infrastructure services and Monitoring services while allowing externally published applications.

Decision

Docker shall use multiple functional bridge networks.

Current design:

Infrastructure
--------------
Homepage
Forgejo
Vaultwarden
Portainer
Nginx Proxy Manager

Monitoring
----------
Uptime Kuma

Future
------
Security
Automation
Cyber Range

Nginx Proxy Manager is permitted to participate in every network containing published web applications.

Application containers remain within their functional network.

Consequences

Positive

Least privilege
Enterprise segmentation
Reduced lateral movement
Better scalability
Easier troubleshooting

Negative

NPM must be attached to additional networks as new service groups are introduced.
Documentation Review
IP Address Registry

No changes required.

Current addresses remain correct.
