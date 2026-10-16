<!-- Converted from Word document: Project_Polaris_Active_Directory_Milestone_Closeout_v1.0.docx -->

**PROJECT POLARIS**

**Active Directory Milestone Closeout**

Formal Closeout and Publication Record

| **Control field** | **Value**                                                  |
|-------------------|------------------------------------------------------------|
| Document ID       | POLARIS-AD-CLOSEOUT-001                                    |
| Version           | 1.0                                                        |
| Effective date    | 2026-08-15                                                 |
| Status            | Implementation Complete / Frozen                           |
| Environment       | Personal homelab                                           |
| Forest and domain | ad.polaris / AD                                            |
| Systems in scope  | DC01, CA01, ADMIN-WS, WS01, WS02                           |
| Predecessor       | RB-010 v1.0 — PKI implementation complete                  |
| Next milestone    | Cyber-range build and remaining Project Polaris milestones |

**Closeout decision:** Accept and freeze the Project Polaris Active Directory milestone. The directory, DNS, time, PKI integration, administrative access model, Group Policy baseline, recovery artifacts, and five-system validation gates are complete. Two homelab exceptions and one recovered service-start observation remain documented and accepted as stated in this record.

# **Executive Closeout Statement**

The ad.polaris forest is operational and ready to serve as the identity and administrative foundation for the Project Polaris cyber range. DC01 provides the current single-domain-controller Active Directory, DNS, Global Catalog, and FSMO functions. CA01 provides domain-integrated certificate issuance under the offline Polaris Root CA. ADMIN-WS is the dedicated administrative workstation. WS01 and WS02 are Tier 2 user workstations.

The final state was validated after DC01 was returned to the built-in Domain Controllers OU, the production GPO links were reconciled, the eight-GPO set was backed up, and new recovery points were created. Command-validated results are distinguished from operator-attested protected VM backups throughout this record.

## **Acceptance Summary**

| **Control area**     | **Final state**                                                                        |
|----------------------|----------------------------------------------------------------------------------------|
| AD DS and DNS        | Healthy; core dcdiag, DNS, LDAP, Kerberos, SYSVOL, NETLOGON, and service gates passed  |
| PKI                  | Two-tier PKI operational; CA01 and ADMIN-WS certificate path validated                 |
| Administrative model | Central administration from ADMIN-WS using AD\domain-admin; delegated paths verified |
| Group Policy         | Eight GPOs present; final links and six-setting baselines validated                    |
| Recovery             | GPO, DC01 System State, CA role-aware, and protected VM backup layers complete         |
| Exceptions           | AD-EXC-001 and AD-EXC-002 accepted for this homelab                                    |
| Observation          | AD-OBS-001 recovered without intervention; monitor for recurrence                      |

# **As-Built Architecture**

## **System Roles and Placement**

| **System** | **Primary function**                                                   | **Final placement and accepted state**                                                                         |
|------------|------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------|
| DC01       | AD DS, DNS, Global Catalog, all FSMO roles, domain time authority      | OU=Domain Controllers,DC=ad,DC=polaris; Windows Server 2019 Standard Evaluation; 192.168.10.40                 |
| CA01       | Enterprise Subordinate Certification Authority                         | OU=Certificate Servers,OU=Tier 0,DC=ad,DC=polaris; Polaris Issuing CA; Windows Server 2019 Standard Evaluation |
| ADMIN-WS   | Dedicated administrative workstation and validated enrollment endpoint | OU=Administrative Workstations,OU=Tier 0,DC=ad,DC=polaris; Windows 11 Pro                                      |
| WS01       | Tier 2 user workstation                                                | OU=Standard Workstations,OU=Tier 2,DC=ad,DC=polaris; Windows 10 Pro                                            |
| WS02       | Tier 2 user workstation                                                | OU=Standard Workstations,OU=Tier 2,DC=ad,DC=polaris; Windows 11 Pro                                            |
| ROOTCA01   | Standalone offline trust anchor                                        | Workgroup-isolated root CA; Polaris Root CA; governed by RB-010                                                |

## **Forest, Domain, and Site**

| **Property**            | **Accepted value**                         |
|-------------------------|--------------------------------------------|
| Forest name             | ad.polaris                                 |
| Domain name             | ad.polaris                                 |
| NetBIOS name            | AD                                         |
| Forest functional level | Windows Server 2016 Forest                 |
| Domain functional level | Windows Server 2016 Domain                 |
| AD site                 | Default-First-Site-Name                    |
| AD subnet               | 192.168.10.0/24 mapped to the primary site |
| Domain controllers      | One: DC01                                  |
| FSMO placement          | All five roles on DC01                     |
| AD Recycle Bin          | Enabled                                    |
| Machine account quota   | 0                                          |

## **DNS and Time Topology**

- DC01 resolves DC01.ad.polaris to 192.168.10.40 and publishes LDAP and Kerberos SRV records.

- DC01 uses its local DNS service and forwards unresolved queries to 192.168.10.1.

- DC01 is configured with 192.168.10.1, time.cloudflare.com, and time.windows.com as NTP candidates.

- CA01, ADMIN-WS, WS01, and WS02 obtain domain time from DC01.

- Final NTP reachability and time-source validation passed.

# **Directory Structure and Placement**

## **Protected OU Baseline**

The production OU structure is protected from accidental deletion. The Tier 0 custom Domain Controllers OU remains preserved and empty; DC01 is intentionally located in the built-in Domain Controllers OU so domain-controller diagnostics and conventional DC policy behavior remain correct.

| **Tier** | **Core OUs**                                                    | **Purpose**                                                       |
|----------|-----------------------------------------------------------------|-------------------------------------------------------------------|
| Built-in | Domain Controllers                                              | Active domain-controller computer objects; contains DC01          |
| Tier 0   | Privileged Groups, Privileged Users, Service Accounts           | Privileged identities and groups                                  |
| Tier 0   | Certificate Servers, Administrative Workstations                | CA01 and ADMIN-WS                                                 |
| Tier 0   | Custom Domain Controllers                                       | Preserved empty; no production DC objects and no direct GPO links |
| Tier 1   | Infrastructure Servers, Management Servers, Certificate Servers | Reserved server-management structure; no current Tier 1 systems   |
| Tier 2   | Standard Workstations, Users                                    | WS01, WS02, and standard user identities                          |

## **Identity Placement**

| **Identity**           | **Final placement**                            | **Intended use**                                                           |
|------------------------|------------------------------------------------|----------------------------------------------------------------------------|
| lab-admin               | OU=Users,OU=Tier 2,DC=ad,DC=polaris            | Standard daily-use account; member of GG-Standard-Users                    |
| domain-admin         | OU=Privileged Users,OU=Tier 0,DC=ad,DC=polaris | Central administrative account used from ADMIN-WS                          |
| Built-in Administrator | Default Users container                        | Break-glass Domain Admin; removed from Enterprise Admins and Schema Admins |
| Guest                  | Default Users container                        | Disabled                                                                   |
| krbtgt                 | Default Users container                        | Disabled as expected; KDC service account                                  |

## **Group and Delegation Model**

The implemented model uses global role groups nested into domain-local permission groups. The central administrative exception deliberately gives domain-admin effective administration paths across all tiers.

| **Role group**           | **Permission path**                    | **Accepted use**                     |
|--------------------------|----------------------------------------|--------------------------------------|
| GG-Domain-Admins-Managed | Nested into Domain Admins              | Managed domain administration        |
| GG-PKI-Admins            | Nested into DL-CA-Admins               | PKI and CA administration            |
| GG-Server-Admins         | Nested into DL-Server-LocalAdmins      | Tier 1 server administration         |
| GG-Workstation-Admins    | Nested into DL-Workstation-LocalAdmins | Tier 2 workstation administration    |
| GG-Standard-Users        | Standard-user authorization path       | Daily-use account authorization      |
| GG-Service-Accounts      | Nested into DL-Service-Logon           | Reserved service-logon authorization |

Additional provisioned domain-local groups are DL-Remote-Desktop-Users, DL-FileShare-Access, and DL-Service-Logon. GG-IT is retained as a general IT role group. All thirteen planned custom groups and all five required AGDLP nesting relationships validated successfully.

# **Privileged Administration Model**

## **Central Administration Decision**

ADMIN-WS is the primary administrative workstation for the entire Active Directory structure. The refreshed AD\domain-admin token contains the following required authorization groups:

- Domain Admins

- GG-Domain-Admins-Managed

- GG-PKI-Admins

- GG-Server-Admins

- GG-Workstation-Admins

The workstation and server delegated groups are deployed through Group Policy Preferences using an **Update** action that preserves existing local Administrators members. WS01 and WS02 both validated AD\DL-Workstation-LocalAdmins in the local Administrators group. The domain-admin session validated as a local administrator through the delegated path.

## **Break-Glass Boundary**

The built-in Administrator account remains an effective Domain Admin for emergency recovery but is no longer a direct member of Enterprise Admins or Schema Admins. The managed role group remains nested into Domain Admins. This retains emergency domain recovery capability while removing unnecessary forest-wide direct memberships.

# **Group Policy Baseline**

## **Authoritative Eight-GPO Inventory**

| **GPO**                                         | **GPO ID**                           | **Direct target**                  |
|-------------------------------------------------|--------------------------------------|------------------------------------|
| Default Domain Controllers Policy               | 6ac1786c-016f-11d2-945f-00c04fb984f9 | Built-in Domain Controllers OU     |
| Default Domain Policy                           | 31b2f340-016d-11d2-945f-00c04fb984f9 | DC=ad,DC=polaris                   |
| POLARIS-T0-Administrative-Workstations-Baseline | 00000000-0000-0000-0000-000000000018 | Tier 0 Administrative Workstations |
| POLARIS-T0-Certificate-Servers-Baseline         | 00000000-0000-0000-0000-000000000019 | Tier 0 Certificate Servers         |
| POLARIS-T0-Domain-Controllers-Baseline          | 00000000-0000-0000-0000-000000000020 | Built-in Domain Controllers OU     |
| POLARIS-T1-Servers-Baseline                     | 00000000-0000-0000-0000-000000000021 | Tier 1                             |
| POLARIS-T2-Users-Baseline                       | 00000000-0000-0000-0000-000000000022 | Tier 2 Users                       |
| POLARIS-T2-Workstations-Baseline                | 00000000-0000-0000-0000-000000000023 | Tier 2 Standard Workstations       |

The two built-in Domain Controllers OU links are enabled and not enforced. The Polaris domain-controller baseline has link order 1; Default Domain Controllers Policy has link order 2. The redundant links formerly attached to the custom Tier 0 Domain Controllers OU were removed after the DC01 move.

## **Six-Setting Computer Baseline**

| **Setting**                                                 | **Accepted value** |
|-------------------------------------------------------------|--------------------|
| Do not store LAN Manager hash value on next password change | Enabled / 1        |
| WDigest UseLogonCredential                                  | Disabled / 0       |
| Insecure SMB guest authentication                           | Disabled / 0       |
| PowerShell script-block logging                             | Enabled / 1        |
| AutoRun                                                     | Disabled / 255     |
| Password reveal button                                      | Disabled / 1       |

The six settings were validated on DC01, CA01, ADMIN-WS, WS01, and WS02. The five computer baselines are computer-settings-only. The Tier 2 Users baseline is user-settings-only.

## **Domain Account Policy**

| **Policy element**             | **Accepted value**               |
|--------------------------------|----------------------------------|
| Minimum password length        | 12 characters                    |
| Maximum password age           | 0 days / passwords do not expire |
| Minimum password age           | 1 day                            |
| Password history               | 24                               |
| Complexity                     | Enabled                          |
| Reversible encryption          | Disabled                         |
| Account lockout threshold      | 10 invalid attempts              |
| Account lockout duration       | 15 minutes                       |
| Lockout observation window     | 15 minutes                       |
| Fine-grained password policies | None                             |

All accounts are governed by this domain policy; no fine-grained policy overrides exist. The homelab exception and its compensating context are recorded as AD-EXC-001.

# **PKI Integration Status**

RB-010 v1.0 is the controlling record for the Project Polaris two-tier PKI. This Active Directory closeout confirms the integrated state without reopening the frozen PKI implementation.

| **Component**                | **Validated state**                                                                          |
|------------------------------|----------------------------------------------------------------------------------------------|
| ROOTCA01                     | Offline standalone root; Polaris Root CA trust anchor                                        |
| CA01                         | Enterprise Subordinate CA; Polaris Issuing CA; CertSvc Running/Automatic                     |
| Issuing CA certificate       | Private key present; chain status NoError; valid through 2036-08-13                          |
| ADMIN-WS machine certificate | Subject CN=ADMIN-WS.ad.polaris; private key present; chain NoError; valid through 2027-08-13 |
| Enrollment proof             | Machine certificate issued by CA01 and correlated to CA request 0x7                          |

CA01 uses DC01 for DNS, resolves the domain, discovers the domain controller, applies its Tier 0 certificate-server baseline, and obtains time from DC01. Its secure channel and issuing function validated successfully.

# **Final Validation Register**

## **Consolidated System Gates**

| **Gate** | **Evidence type** | **Final evidence**                                                                                                         | **Result** |
|----------|-------------------|----------------------------------------------------------------------------------------------------------------------------|------------|
| DC01     | Command validated | Built-in DC OU; services, SYSVOL/NETLOGON, DNS, replication, GPO, MachineAccount, time, and core dcdiag gates passed       | PASS       |
| CA01     | Command validated | Correct OU; Enterprise Subordinate CA; service, private key, chain, DNS, DC discovery, GPO, and time gates passed          | PASS       |
| ADMIN-WS | Command validated | Correct OU; secure channel, DNS, RSAT, baseline, PKI client certificate, time, and refreshed five-group admin token passed | PASS       |
| WS01     | Command validated | Correct OU; DNS, LDAP, Kerberos, delegated local admin, baseline, GPO, and time gates passed                               | PASS       |
| WS02     | Command validated | Correct OU; DNS, LDAP, Kerberos, delegated local admin, baseline, GPO, time, and refreshed admin token passed              | PASS       |

## **DC01 OU Remediation**

DC01 was moved from OU=Domain Controllers,OU=Tier 0,DC=ad,DC=polaris to OU=Domain Controllers,DC=ad,DC=polaris. The existing computer object was moved rather than recreated, preserving its object identity.

Before the move, the Polaris DC baseline was linked to the built-in OU. After the move, both required policies applied, the MachineAccount diagnostic passed, dcdiag /q became clean apart from the separately analyzed historical SystemLog event, and the redundant custom-OU links were removed. The custom OU remains protected and empty.

## **Recovered ADWS Startup Observation**

At 2026-08-15 15:22:50, DC01 logged Service Control Manager events 7009 and 7000 because Active Directory Web Services did not complete its initial start within 30 seconds after boot. ADWS subsequently started at 15:23:13, listened on TCP 9389, answered AD queries, and produced no new failure after the current service start.

This is recorded as AD-OBS-001. No service timeout modification, event-log clearing, or other remediation was applied. Recurrence should be investigated; the single recovered startup event does not block milestone acceptance.

# **Backup and Recovery Register**

## **Authoritative Application-Aware Backups**

| **Recovery asset**      | **Validated destination**                                                                                            | **Accepted evidence**                                                                                                             |
|-------------------------|----------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------|
| Eight-GPO backup        | NAS share \\192.168.10.4\Backups; folder ActiveDirectory\GPO-Backups\Post-DC-OU-Remediation-20260815-105722          | 8 successful and unique backup IDs; 8 physical sets; 37 valid hash-manifest entries; all reports present                          |
| DC01 System State       | NAS share \\192.168.10.4\Backups; folder ActiveDirectory\DC01-SystemState\Post-DC-OU-Remediation-20260815-121223     | Exit code 0; catalog contains System State; 20 files; 16,090,591,596 bytes                                                        |
| CA01 role-aware backup  | NAS share \\192.168.10.4\Backups; folder ActiveDirectory\CertificateServices\CA01\AD-Milestone-Final-20260814-142826 | CA database and private key, registry, templates, public certificate, and published artifacts; local/NAS counts and bytes matched |
| CA01 local staging copy | C:\Polaris\CA-Backups\AD-Milestone-Final-20260814-142826                                                             | Validated local recovery copy before NAS transfer                                                                                 |

Pre-remediation backups are retained as rollback points. The post-remediation assets above are the authoritative configuration and application-aware recovery set for this milestone.

## **Protected Virtual-Machine Backups**

Full protected Proxmox backups of DC01, CA01, ADMIN-WS, WS01, and WS02 were completed to NAS storage after the final state was established. Completion of this layer is recorded by operator attestation. These backups provide whole-machine recovery convenience, particularly for the Windows Server 2019 evaluation rebuild cycle.

Application-aware recovery data remains authoritative for AD DS and AD CS:

- Use the DC01 System State backup and an Active Directory-aware recovery procedure for directory recovery.

- Use the CA01 role-aware backup for CA database, private-key, registry, template, and publication recovery.

- Treat protected VM backups as complementary whole-machine recovery points, not substitutes for AD- or CA-aware recovery.

- Do not live-clone or casually roll back a domain controller. Validate hypervisor and Windows recovery behavior before restoration.

## **Recommended Recovery Order**

1.  Restore required network, DNS-forwarding, firewall, and NAS access dependencies.

2.  Recover DC01 and validate AD DS, DNS, SYSVOL, NETLOGON, time, and FSMO ownership.

3.  Recover CA01 and validate the issuing CA database, private key, chain, publication points, and CertSvc.

4.  Recover ADMIN-WS and validate administrative authorization and the client certificate.

5.  Recover WS01 and WS02, then validate secure channels, DNS, Group Policy, and delegated local administration.

# **Accepted Exceptions and Tracked Conditions**

## **Accepted Exceptions**

| **ID**     | **Decision**                                                            | **Scope and compensating context**                                                                                                                                                                                                                  |
|------------|-------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| AD-EXC-001 | Use a 12-character minimum and no password expiration for every account | Personal homelab behind two separate pfSense firewalls; complexity, 24-password history, lockout controls, role separation, and later password replacement remain in place. The owner accepts the departure from stronger Tier 0 password guidance. |
| AD-EXC-002 | Permit domain-admin to administer all tiers from ADMIN-WS             | Central administration is preferred for the homelab. ADMIN-WS is dedicated, the account is separate from daily use, access follows managed groups, and six hardening settings apply. The owner accepts cross-tier credential exposure risk.         |

These exceptions are intentional architecture decisions. A future change to either decision requires a new evidence-backed revision; the closeout must not silently reinterpret them.

## **Observation and Operational Conditions**

| **ID**     | **Condition**                                               | **Required treatment**                                                                                                |
|------------|-------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------|
| AD-OBS-001 | Recovered ADWS startup timeout after final restart          | Monitor. Investigate only if the failure recurs or ADWS remains unavailable.                                          |
| AD-OPS-001 | DC01 is the only domain controller and holds all FSMO roles | Maintain tested backups; recognize that DC01 loss removes AD/DNS availability until recovery.                         |
| AD-OPS-002 | DC01 and CA01 run Windows Server 2019 Evaluation            | Track the 180-day lifecycle and rebuild before expiration; retain application-aware and full-machine recovery points. |
| AD-OPS-003 | ROOTCA01 is offline                                         | Preserve offline custody, recovery material, and renewal planning under PKI change control.                           |

# **Operational Handoff and Freeze Rules**

## **Frozen Baseline**

The following state is frozen at publication:

- The OU placement and GPO links documented in this record.

- The authoritative eight-GPO inventory and six-setting computer baseline.

- The group and delegation model, including the two accepted exceptions.

- DC01 placement in the built-in Domain Controllers OU.

- The RB-010 PKI architecture and CA01 issuing configuration.

- The listed post-remediation GPO, System State, CA, and protected VM recovery points.

Future break/fix or planned changes must record the reason, target, implementation result, validation evidence, and any required backup refresh. Editorial updates may clarify wording but must not silently alter the accepted architecture.

## **Routine Health Gates**

- Confirm critical DC services, SYSVOL, NETLOGON, DNS, and time.

- Run targeted dcdiag gates and review new SystemLog errors rather than clearing history.

- Confirm CA01 CertSvc, CA identity, chain status, DNS, secure channel, and time.

- Validate required GPO application and all six local baseline settings on representative systems.

- Confirm AD\domain-admin token memberships after authorization changes or sign-in refresh.

- Confirm backup catalog visibility and periodically perform isolated restore testing.

## **Milestone Transition**

The Active Directory milestone is complete and frozen. The environment may now proceed to the Project Polaris cyber-range build and remaining milestones. New cyber-range workloads should consume the established DNS, identity, administrative, PKI, and backup services without redefining this baseline.

# **Formal Acceptance**

**Decision:** Accept and freeze the Project Polaris Active Directory milestone.

**Effective date:** 2026-08-15.

**Accepted outcome:** The ad.polaris directory, two-tier PKI integration, central administration model, Group Policy baseline, recovery layers, and five-system health gates are operational. AD-EXC-001 and AD-EXC-002 are accepted homelab exceptions. AD-OBS-001 is a recovered, monitored observation.

**Transition authorization:** Proceed to the cyber-range build and remaining Project Polaris milestones under the frozen baseline and documented change-control rules.

# **Evidence Appendix A — Evidence Index**

| **Evidence item**                                                                                                                                    | **Result**                       |
|------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------|
| Forest/domain identity, FSMO, DNS, site, replication, time, OU, groups, GPOs, password policy, trust, delegation, and recovery readiness inventories | Completed and reviewed           |
| RB-010 Step 5.8 PKI acceptance validation                                                                                                            | PASS; RB-010 v1.0 published      |
| DC01 move and post-move policy/MachineAccount validation                                                                                             | PASS                             |
| Final GPO backup and corrected physical/hash validation                                                                                              | PASS                             |
| DC01 System State backup and catalog validation                                                                                                      | PASS                             |
| CA01 role-aware backup and NAS copy validation                                                                                                       | PASS                             |
| DC01 final health and ADWS recovery analysis                                                                                                         | PASS with AD-OBS-001             |
| CA01 final health                                                                                                                                    | PASS                             |
| ADMIN-WS final health and refreshed admin token                                                                                                      | PASS                             |
| WS01 final health                                                                                                                                    | PASS                             |
| WS02 final health and refreshed admin token                                                                                                          | PASS                             |
| Five protected Proxmox VM backups to NAS                                                                                                             | Complete by operator attestation |

# **Appendix B — Quick Validation Commands**

Run these commands from an elevated Windows PowerShell session on the applicable system. They are concise operational checks, not substitutes for the complete evidence captured during milestone implementation.

## **DC01**

dcdiag.exe /q

dcdiag.exe /test:DNS

repadmin.exe /replsummary

Get-Service DFSR,DNS,KDC,Netlogon,NTDS,W32Time

Get-ADDomainController -Identity DC01 \|

Select-Object HostName,Site,IPv4Address,IsGlobalCatalog

## **CA01**

Get-Service CertSvc

certutil.exe -getreg CA\CommonName

certutil.exe -getreg CA\CAType

certutil.exe -ping

nltest.exe /sc_verify:ad.polaris

## **Domain Member**

whoami.exe

whoami.exe /groups

gpresult.exe /Scope Computer /R

nltest.exe /sc_verify:ad.polaris

Resolve-DnsName DC01.ad.polaris

w32tm.exe /query /source

# **Appendix C — Publication Notes**

- This document contains no passwords, private-key material, or NAS credentials.

- Dates, paths, identifiers, membership results, and validation outcomes are transcribed from the execution evidence supplied during the milestone.

- Protected VM backup completion is an operator attestation; application-aware backups include command-validated inventories.

- RB-010 remains the authoritative detailed record for ROOTCA01, CA01 establishment, and Step 5.8 PKI acceptance.
