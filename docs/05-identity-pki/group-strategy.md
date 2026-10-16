# Group Strategy

## Model

Project Polaris uses AGDLP.

Accounts → Global Groups → Domain Local Groups → Permissions

## Initial Global Groups

- GG-Domain-Admins-Managed
- GG-Server-Admins
- GG-Workstation-Admins
- GG-Standard-Users
- GG-Service-Accounts
- GG-IT

## Initial Domain Local Groups

- DL-Server-LocalAdmins
- DL-Workstation-LocalAdmins
- DL-Remote-Desktop-Users
- DL-FileShare-Access
- DL-Service-Logon

## Rules

- Do not assign permissions directly to users.
- Use groups for access control.
- Separate admin, standard, and service identities.
- Cyber range groups are separate and not reused in production.
