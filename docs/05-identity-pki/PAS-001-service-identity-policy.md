Project Polaris Architecture Standard
PAS-001 — Service Identity Standard (Frozen)
Principle

A Project Polaris service identity is not a user account. It is a dedicated security principal that owns exactly one operational capability.

The service identity represents the authorization boundary.

The software (PowerShell script, Windows service, executable, scheduled task, or container) is merely the implementation operating within that boundary and may be replaced without changing the identity.

Naming Convention

All Project Polaris service identities shall use:

svc<function>

Examples:

svcrecovery
svcrelay
svcbackup
svcmonitor
svcpki
svcautomation

Service identities shall be named for the capability they own, not the technology implementing that capability.

Preferred:

svcrecovery

Not preferred:

svcpowershell
svcdocker
svcssh

because PowerShell, Docker, and SSH are implementation details rather than responsibilities.

Single Capability Rule

Each service identity owns exactly one capability.

Example:

Identity	Responsibility
svcrecovery	Recovery orchestration
svcrelay	Secure broker / IPC relay
svcbackup	Backup orchestration
svcmonitor	Monitoring
svcpki	Certificate operations

Service identities shall not accumulate unrelated responsibilities.

Stable Identity Principle

The service identity remains constant even when the implementation changes.

Example:

Today

svcrecovery
    │
    └── Invoke-RecoveryArtifactTransfer.ps1

Future

svcrecovery
    │
    └── RecoveryService.exe

Only the implementation changes.

Permissions, ACLs, documentation, Vaultwarden entries, and audit records continue to reference the same identity.

Authorization Principle

Permissions are granted to the service identity, never to the implementation.

Examples include:

NTFS ACLs
Named Pipe ACLs
SSH Keys
Windows Service Logon
Scheduled Tasks
Certificates
Secrets
Least Privilege

Each identity receives only the permissions required for its capability.

For example:

svcrecovery

May:

Read recovery workspace
Write recovery logs
Submit broker requests

May Not:

SSH to Docker01
Modify repository artifacts
Access relay private keys
svcrelay

May:

Receive broker requests
Authenticate to Docker01
Invoke relay wrapper

May Not:

Modify recovery workspace
Read recovery artifacts
Access backup infrastructure
Replaceable Implementation Principle

The following may change without changing the service identity:

PowerShell script
Executable
Windows Service
Scheduled Task
Container
Runtime (.NET, PowerShell, Go, Rust, etc.)

The identity represents the security boundary rather than the implementation technology