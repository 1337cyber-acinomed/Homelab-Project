Polaris Configuration Governance Policy

Every milestone that modifies infrastructure must conclude with updating and validating the following authoritative documents before the milestone is considered complete.

Required Updates
1. IP Address Plan

Authoritative source for:

Static IP assignments
Reserved ranges
Infrastructure addressing
Service locations

File:

architecture/network/IP-ADDRESS-PLAN.md
2. Hostname Registry

Authoritative source for:

Infrastructure hostnames
Production servers
Cyber Range hosts
Future reserved names
3. DNS Registry

Authoritative source for:

Host A records
Service aliases
Future CNAMEs
Reverse lookup expectations

(New during Milestone 8)

4. Port Registry

Authoritative source for:

Standard ports
Reverse proxy ports
Container mappings
Administrative ports

File:

architecture/network/PORT-REGISTRY.md
5. ADR Index

Every milestone that introduces architectural changes must determine if:

Existing ADR requires update
New ADR required
No ADR required
6. Build Guide

If implementation changes...

Build Guide changes.

7. Recovery Guide

If deployment changes...

Recovery Guide changes.

Milestone Exit Criteria

From now on, every milestone is complete only when:

Infrastructure
        │
        ▼
Validation
        │
        ▼
Documentation
        │
        ▼
Git Commit
        │
        ▼
Milestone Complete

No exceptions.
