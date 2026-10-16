<!-- Converted from Word document: homelab-infrastructure/architecture/computer/PKI-001_Project_Polaris_PKI_Architecture.docx -->

# PKI-001 – Project Polaris Public Key Infrastructure Architecture

Document ID: PKI-001  
Version: 1.0 (Draft)  
Status: Architecture Design  
Owner: Project Polaris

## Part 1 – Executive Overview

### Purpose

This document defines the authoritative Public Key Infrastructure (PKI) architecture for Project Polaris. The PKI establishes a centralized trust framework for secure identity, authentication, encryption, and certificate lifecycle management. It replaces isolated self-signed certificates with a unified enterprise trust model while emphasizing recoverability, simplicity, and operational discipline.

### Scope

Applies to Active Directory Certificate Services (AD CS), CA01, certificate templates, Active Directory auto-enrollment, internal TLS certificates, infrastructure authentication certificates, and future enterprise, cyber, AI, and automation services. Operational procedures will be documented separately.

### Objectives

• Establish a single authoritative trust anchor.  
• Support centralized issuance, renewal, and revocation.  
• Integrate with Active Directory.  
• Provide a recoverable, documented PKI.  
• Support future enterprise expansion without redesign.

### Design Philosophy

Project Polaris follows an enterprise-inspired, homelab-appropriate PKI strategy. Design for the next milestone, but optimize for the current one.

### Relationship to Project Polaris

PKI is a shared enterprise service spanning the infrastructure, enterprise, cyber operations, operations, and intelligence layers.

### Architectural Principles

• Centralized trust.  
• Governed certificate lifecycle.  
• Recoverability before convenience.  
• Stable trust hierarchy.  
• Backup, validation, documentation, and recoverability for every significant PKI change.

### Rebuildability by Design

CA01 shall be intentionally rebuilt after backup automation is complete using only documented procedures and validated recovery artifacts. Recovery is demonstrated—not assumed.

### Enterprise Fidelity Principle

If an enterprise would implement a capability, Project Polaris should implement it unless the operational complexity significantly exceeds the educational value. Simplifications must be intentional and documented.

### Operational Independence Principle

Enterprise identity services are primary, but no single component shall become a single point of administrative dependency. Secondary recovery access shall always exist for critical infrastructure.

**PKI-001  
Project Polaris Public Key Infrastructure Architecture**  
Part 2 - PKI Architecture

| **Field**   | **Value**                    |
|-------------|------------------------------|
| Document ID | PKI-001                      |
| Version     | 1.0 (Draft)                  |
| Status      | Approved Architecture Design |
| Owner       | Project Polaris              |
| Section     | Part 2 - PKI Architecture    |

**Architecture Decision**: Project Polaris will implement a two-tier PKI consisting of an offline standalone root certification authority and an online domain-integrated enterprise issuing certification authority.

**Implementation Gate**: Before provisioning the second PKI virtual machine and committing production resources, the entire Proxmox node and available hardware capacity will be reviewed and fine-tuned to optimize VM placement, CPU allocation, memory allocation, storage, and service availability.

# 1. Trust Hierarchy

> Offline Standalone Root CA (ROOTCA01)  
> \|  
> \| Signs the issuing CA certificate  
> v  
> Online Enterprise Issuing CA (CA01)  
> \|  
> v  
> Users, computers, servers, applications, network devices, and automation identities

## Tier 1 - ROOTCA01

**Role:** Offline standalone root certification authority.

- Not joined to polaris.home.arpa.

- Normally powered off.

- Used only to issue or renew the CA01 issuing certificate, publish a new root CRL, revoke an issuing CA certificate, renew the root CA certificate, or perform planned recovery validation.

- Does not issue end-entity certificates.

- Private key remains unavailable during normal operations.

- Receives no routine inbound network access.

ROOTCA01 is the ultimate trust anchor. Its private key receives the highest protection because compromise of the root key would compromise the entire PKI hierarchy.

## Tier 2 - CA01

**Role:** Online Enterprise subordinate issuing certification authority.

- Joined to polaris.home.arpa.

- Integrated with Active Directory.

- Online during normal operations.

- Publishes and processes certificate templates.

- Supports Group Policy auto-enrollment.

- Issues certificates to users, computers, servers, services, and approved infrastructure.

- Publishes current revocation information.

- Protected by automated configuration backup, CA-native backup, snapshots where appropriate, and validated restore procedures.

# 2. Naming Architecture

| **Component**     | **Proposed Hostname** | **Role**                      |
|-------------------|-----------------------|-------------------------------|
| Offline root      | rootca01              | Standalone offline root CA    |
| Enterprise issuer | ca01                  | Online Enterprise issuing CA  |
| Publication alias | pki.polaris.home.arpa | Stable HTTP CDP/AIA namespace |

## Certification Authority Service Names

> Project Polaris Root CA  
> Project Polaris Enterprise Issuing CA 01

The certification authority identity is intentionally separated from the server hostname. A future server migration may change the host that runs the CA service while preserving the CA common name and trust hierarchy.

# 3. Active Directory Integration

- CA01 will be domain joined and installed as an Enterprise subordinate CA.

- CA01 will use Active Directory certificate templates and publish enrollment services in the directory.

- Group Policy will provide computer and user auto-enrollment where approved.

- PKI administration will use delegated security groups rather than relying solely on broad domain administration.

- ROOTCA01 will remain outside the domain.

- The root certificate and root CRL will be transferred and published through controlled procedures.

This separation prevents compromise of Active Directory from automatically providing access to the offline root private key.

# 4. Certificate Validity Strategy

| **Certificate Class**                   | **Proposed Validity** | **Renewal Planning**               |
|-----------------------------------------|-----------------------|------------------------------------|
| Root CA certificate                     | 20 years              | Review and plan renewal at year 10 |
| Issuing CA certificate                  | 10 years              | Review and plan renewal at year 5  |
| Server and computer certificates        | 1 year                | Automatic renewal                  |
| User certificates                       | 1 year                | Automatic renewal where applicable |
| Specialized infrastructure certificates | 1-2 years             | Template controlled                |
| Short-lived automation certificates     | Defined later         | Minimize lifetime where practical  |

These values are Project Polaris design targets and will be finalized before CA installation. CA certificate validity must be long enough to support the full validity period of certificates it issues. CAPolicy.inf will be prepared before root CA installation to establish root policy and constraints.

# 5. Cryptographic Architecture

| **Component**                      | **Algorithm**       | **Key Size**         | **Hash**             |
|------------------------------------|---------------------|----------------------|----------------------|
| ROOTCA01                           | RSA                 | 4096-bit             | SHA-256              |
| CA01                               | RSA                 | 4096-bit             | SHA-256              |
| General server/client certificates | RSA                 | 2048-bit or stronger | SHA-256              |
| Future specialized templates       | Template controlled | Compatibility based  | Approved modern hash |

RSA is selected for Version 1.0 because it provides broad compatibility across Windows, firewalls, virtualization platforms, reverse proxies, network appliances, and applications in the lab. Experimental algorithms will remain isolated from the production trust hierarchy.

# 6. CRL and AIA Architecture

**Stable publication namespace:** http://pki.polaris.home.arpa/pki/

Certificates will reference a stable service alias rather than a CA server hostname, preventing issued certificates from becoming coupled to the physical server that hosts CA01.

> ROOTCA01  
> \|-- Root CA certificate  
> \`-- Root CRL  
> \| controlled transfer  
> v  
> Static HTTP PKI publication point  
> pki.polaris.home.arpa  
> \|-- Root certificate  
> \|-- Root CRL  
> \|-- CA01 certificate  
> \`-- CA01 CRLs

## Proposed Revocation Schedule

| **Authority** | **Base CRL** | **Delta CRL** | **Operational Note**                                            |
|---------------|--------------|---------------|-----------------------------------------------------------------|
| ROOTCA01      | 12 months    | Disabled      | Renew and publish during planned root maintenance with overlap  |
| CA01          | 7 days       | 1 day         | Monitor publication and publish before maintenance or migration |

# 7. Publication Service Independence

> DNS alias: pki.polaris.home.arpa  
> \|  
> v  
> Static HTTP publication service on Docker01  
> \|  
> v  
> Read-only PKI publication directory

- Clients can retrieve existing CA certificates and current revocation data while CA01 is offline.

- Existing certificates continue to support services while valid and while required revocation information remains current.

- New enrollment, renewal, and revocation processing remains unavailable until CA01 is restored.

- Critical services retain local, console, or key-based emergency access.

Version 1.0 will use one stable HTTP publication alias plus Active Directory publication. A secondary publication point may be added later if its learning value justifies the operational complexity.

# 8. Availability Model

CA01 is critical but will not be implemented as a clustered service. The architecture prioritizes recoverability over CA service high availability.

| **During a CA01 Outage - Continues**                       | **Temporarily Unavailable**                 |
|------------------------------------------------------------|---------------------------------------------|
| Active Directory authentication                            | New certificate enrollment                  |
| Existing TLS and certificate-based services                | Certificate renewal requiring CA processing |
| Proxmox local access                                       | Certificate revocation processing           |
| pfSense local or console access                            | New template publication                    |
| SSH key authentication                                     | CA administration                           |
| CRL/AIA retrieval from the independent publication service |                                             |

# 9. Backup Architecture

## CA01 Required Recovery Assets

- CA database.

- CA private key and certificate.

- CA configuration and registry export.

- Certificate templates and Active Directory PKI object inventory.

- CAPolicy configuration where applicable.

- CRL and AIA configuration.

- Published certificate and CRL files.

- System State backup where appropriate.

- VM configuration and approved snapshot.

- Project Polaris collector archive.

- Recovery credentials and key passwords stored securely.

- Documented rebuild procedure.

## ROOTCA01 Required Recovery Assets

- Root CA private key and certificate.

- Root CA database.

- Root CA configuration.

- CAPolicy.inf.

- Root CRL.

- CA01 issued subordinate certificate records.

- Secure offline copy of the key backup.

- Full rebuild documentation.

No single recovery artifact will be treated as sufficient by itself.

# 10. Rebuild and Acceptance Architecture

> Build ROOTCA01  
> v  
> Build and sign CA01  
> v  
> Configure templates and publication  
> v  
> Integrate automated backups  
> v  
> Capture validated snapshots and recovery artifacts  
> v  
> Issue controlled test certificates  
> v  
> Delete or treat CA01 as failed  
> v  
> Rebuild CA01 from documented recovery assets  
> v  
> Validate existing trust and certificate issuance  
> v  
> Review collector behavior and modify only where necessary  
> v  
> Declare PKI production-ready

- The CA identity is preserved.

- The original private key is restored.

- The CA database is restored.

- Previously issued certificates remain trusted.

- CRL and AIA locations remain valid.

- Enrollment resumes.

- Backup automation recognizes the rebuilt CA.

- Emergency access remains available throughout recovery.

# 11. Pre-Implementation Node and Capacity Review

Before provisioning the two PKI virtual machines, Project Polaris will review the complete Proxmox node and available hardware. The review will ensure that the upgraded hardware is allocated efficiently and that existing VMs remain appropriately sized before the PKI workload is introduced.

- CPU topology, utilization, and overcommit strategy.

- Memory allocation, ballooning, and reserve capacity.

- Storage pool health, free capacity, and backup impact.

- VM placement and start-at-boot priorities.

- Network interface and bridge configuration.

- Resource allocation for ROOTCA01 while temporarily online.

- Resource allocation and uptime requirements for CA01.

- Capacity reserved for future enterprise, cyber range, and AI workloads.

The node review is a mandatory implementation gate and may result in fine-tuning existing VMs before CA01 is built.

# 12. Architectural Decision Summary

| **Decision**      | **Selected Design**                                      |
|-------------------|----------------------------------------------------------|
| Hierarchy         | Two-tier PKI                                             |
| Root CA           | Offline standalone ROOTCA01                              |
| Issuing CA        | Online Enterprise subordinate CA01                       |
| Domain membership | ROOTCA01 workgroup; CA01 domain joined                   |
| Publication       | Stable HTTP alias plus Active Directory                  |
| Daily issuance    | CA01 only                                                |
| Root usage        | Controlled offline operations                            |
| Availability      | Recoverability over clustering                           |
| Emergency access  | Local, console, and key-based secondary access retained  |
| Acceptance        | Mandatory destructive CA01 rebuild                       |
| Capacity gate     | Full node and hardware review before PKI VM deployment   |
| Future expansion  | Additional issuing CA or OCSP without replacing the root |

# References

- Microsoft Learn - PKI design considerations for Active Directory Certificate Services.

- Microsoft Learn - Prepare the CAPolicy.inf file.

- Microsoft Learn - Certification Authority migration guidance.

- Microsoft enterprise PKI guidance describing offline root and subordinate issuing CA hierarchy.

*End of PKI-001 Part 2*

# PKI-001 – Project Polaris Public Key Infrastructure Architecture

Document ID: PKI-001  
Version: 1.0 (Draft)  
Status: Architecture Design  
Owner: Project Polaris

## Parts 3 & 4 – Certificate Hierarchy, Template Strategy, and Operational Design

### Part 3 – Certificate Hierarchy & Template Strategy

This section defines the certificate classes, enrollment methods, lifecycle strategy, template governance, and trust boundaries for the Project Polaris PKI.

#### Key Approved Design Decisions

- Minimum required certificate templates only.

- Automatic enrollment begins with Domain Controllers and a pilot computer group.

- Infrastructure certificates use controlled manual enrollment.

- User authentication templates are designed but deferred.

- Wildcard certificates are deferred in favor of named SAN certificates.

- Key archival and Key Recovery Agents are deferred for Version 1.0.

- Dedicated Active Directory security groups control enrollment permissions.

- Every template requires documented ownership, purpose, lifecycle, and validation.

#### Production Trust Boundary

The production PKI is authoritative only for the production enterprise environment.  
  
No certificates from the production PKI shall be issued to cyber-range systems.  
  
The cyber range will eventually contain its own independent Active Directory forest and Certification Authority. Cross-boundary trust relationships will only be created intentionally as part of approved learning objectives.

#### Production PKI Consumers

- DC01

- CA01

- Admin-WS

- Docker01

- Nginx Proxy Manager

- Vaultwarden

- Forgejo

- Homepage

- Uptime Kuma

- Proxmox

- gateway01

- firewall01

- NAS01

- Future production Windows infrastructure

#### Excluded Systems

- Cyber-FW01 (OPNsense)

- Cyber Active Directory

- Cyber-range Windows infrastructure

- Kali systems

- Disposable cyber-range virtual machines

- Offensive security tooling

#### Trust Boundary Independence

Trust relationships shall not cross security boundaries unless the explicit objective of the exercise is to study or validate cross-boundary trust.  
  
Production identity services trust only production infrastructure. Cyber-range identity services trust only cyber-range infrastructure. Cross-certification is treated as a future learning exercise rather than a default architectural feature.

PKI-001  
Project Polaris Public Key Infrastructure Architecture

**Parts 6 and 7 - Integration Roadmap and Disaster Recovery**

| Document ID | PKI-001                                              |
|-------------|------------------------------------------------------|
| Version     | 1.0 (Draft)                                          |
| Status      | Architecture Design - Approved Working Sections      |
| Owner       | Project Polaris                                      |
| Scope       | Production PKI; Cyber Range (VMIDs 300-399) excluded |

# Part 6 - Integration Roadmap

## 1. Integration Philosophy

The Project Polaris PKI is not implemented for its own sake. It exists to provide a centralized trust framework for secure authentication, encrypted communications, and managed certificate lifecycles across the production enterprise.

- PKI adoption shall occur incrementally.

- Each integration shall be validated before the next integration begins.

- Production trust shall remain separate from the Cyber Range (VMIDs 300-399).

- Existing administrative methods shall remain available until PKI integration has been validated.

- Every integration shall document what the control does, why it improves security, the attacks it mitigates, and the operational trade-offs it introduces.

- Certificates shall be issued only when a documented operational requirement exists.

## 2. Integration Priority Model

Services are integrated in dependency order so the trust foundation is validated before dependent systems consume it.

| Phase                   | Systems                                                                    | Primary PKI Use                                            | Validation Gate                       |
|-------------------------|----------------------------------------------------------------------------|------------------------------------------------------------|---------------------------------------|
| 1 - Core Identity       | ROOTCA01, CA01, Active Directory, DNS                                      | Trust hierarchy and publication                            | CA chain, CRL, AIA, issuance          |
| 2 - Windows Enterprise  | DC01, Admin-WS, approved servers and workstations                          | Auto-enrollment, machine identity, LDAPS, future WinRM/RDP | Pilot enrollment and renewal          |
| 3 - Core Infrastructure | Proxmox, firewall01, gateway01, NAS01                                      | Trusted HTTPS and administrative TLS                       | Manual enrollment and rollback        |
| 4 - Enterprise Services | Docker01, Nginx Proxy Manager, Vaultwarden, Forgejo, Homepage, Uptime Kuma | Internal HTTPS and reverse-proxy trust                     | Client trust and service continuity   |
| 5 - Future Production   | Monitoring, SIEM, APIs, automation, AI services                            | Service identity, TLS, future mTLS                         | Architecture review before enrollment |

## 3. Core Identity Services

ROOTCA01 and CA01 establish the production trust hierarchy. Active Directory and DNS provide enrollment discovery, policy distribution, and stable naming.

### Security justification

- What: Establishes one controlled production trust chain instead of independent self-signed certificates.

- Why: Centralizes issuance, validation, renewal, and revocation.

- Protects against: Rogue or inconsistent certificate authorities, service impersonation, certificate-warning fatigue, and unmanaged expiration.

- Trade-off: Introduces administrative and recovery responsibilities that must be documented and validated.

## 4. Windows Enterprise Infrastructure

Production Windows systems will be the first broad consumers of the PKI.

- Domain Controller Authentication for DC01.

- Pilot computer auto-enrollment through a dedicated security group.

- Expansion to approved production servers and workstations only after pilot validation.

- Future LDAPS, WinRM over HTTPS, and RDP listener certificate integration.

- No automatic enrollment for the Cyber Range (VMIDs 300-399).

### Security justification

- What: Assigns managed machine identities and trusted server certificates.

- Why: Replaces unmanaged or self-signed identities with domain-controlled certificate lifecycles.

- Protects against: Internal service spoofing, man-in-the-middle attacks, weak endpoint identity, and unplanned certificate expiration.

- Trade-off: Requires Group Policy, template governance, and rollback testing.

## 5. Core Infrastructure Integration

Core production infrastructure may consume manually issued certificates from restricted templates.

| System     | Integration   | Primary Benefit                         | Secondary Access Requirement                     |
|------------|---------------|-----------------------------------------|--------------------------------------------------|
| Proxmox    | Trusted HTTPS | Trusted hypervisor administration       | Local Proxmox authentication remains available   |
| firewall01 | Trusted HTTPS | Trusted homelab firewall administration | Local/console recovery remains available         |
| gateway01  | Trusted HTTPS | Trusted home gateway administration     | Local/console recovery remains available         |
| NAS01      | Trusted HTTPS | Trusted storage administration          | Local appliance administration remains available |

## 6. Enterprise Service Integration

- Docker01: trusted host and service administration where supported.

- Nginx Proxy Manager: named SAN certificates for approved internal services.

- Vaultwarden: trusted HTTPS through the reverse proxy, with direct administrative recovery access preserved.

- Forgejo: trusted HTTPS for repository administration and use.

- Homepage and Uptime Kuma: trusted internal HTTPS.

- Future services: reviewed individually before a production template is assigned.

### Security justification

- What: Provides trusted encryption between users and internal applications.

- Why: Ensures clients can verify the identity of the service they are connecting to.

- Protects against: Man-in-the-middle attacks, service impersonation, credential interception, and normalization of invalid-certificate warnings.

- Trade-off: Linux and appliance integrations may require controlled PFX/PEM export and manual renewal procedures.

## 7. Cyber Range Exclusion

The Cyber Range (VMIDs 300-399) is intentionally excluded from the Project Polaris production PKI. It will maintain its own independent identity and trust architecture when Windows production-style services are deployed inside that environment.

- Cyber-FW01 (OPNsense) does not consume the production PKI.

- Cyber-range Active Directory and certificate services will be built independently.

- Cyber-range Windows and Linux systems will not receive production certificates.

- Kali systems, offensive tooling, disposable workloads, malware-analysis systems, and research systems remain outside the production trust chain.

- Cross-boundary trust or cross-certification may be introduced only for a documented learning objective.

### Security justification

- What: Preserves separate trust authorities for production and the Cyber Range (VMIDs 300-399).

- Why: Prevents an intentionally attackable environment from becoming dependent on, or trusted by, production identity services.

- Protects against: Cross-boundary trust abuse, lateral movement, unintended certificate issuance, and compromise propagation.

- Trade-off: A second PKI must be designed and operated inside the Cyber Range (VMIDs 300-399).

## 8. Standalone External Assessment Platform

A standalone Kali Linux laptop may be used as a trusted but temporary external assessment platform. It is neither part of the production trust boundary nor part of the Cyber Range (VMIDs 300-399).

- Not domain joined.

- Not permanently connected to the production network.

- Used for authorized penetration testing, red-team exercises, purple-team validation, hardening verification, detection engineering, and incident-response practice.

- Connected only during approved assessment activity.

- Subject to an explicit rules-of-engagement document before testing production infrastructure.

## 9. Standard Integration Workflow

1.  Perform an architectural review.

2.  Identify the certificate purpose and approved owner.

3.  Select or create the approved template.

4.  Document subject, SAN, validity, renewal, export, and recovery requirements.

5.  Issue the certificate through the approved enrollment method.

6.  Deploy the certificate without removing secondary administrative access.

7.  Validate chain trust, protocol configuration, application function, and rollback.

8.  Update monitoring, backup, SOP, and inventory documentation.

9.  Approve the integration for production.

## 10. Integration Validation Requirements

- Certificate chain validates to Project Polaris Root CA.

- Subject and SAN values match the approved service names.

- Production clients trust the certificate without warning.

- The service uses an approved secure protocol and cipher configuration.

- Renewal and replacement procedures are documented.

- Exported private keys, where required, are encrypted and backed up.

- Monitoring identifies service or certificate failure.

- Emergency administrative access remains functional.

- The Cyber Range (VMIDs 300-399) remains outside the production trust relationship.

## 11. Integration Acceptance Criteria

- The service uses the approved production certificate template.

- Security benefits and mitigated attack classes are documented.

- Operational trade-offs and dependencies are documented.

- Trust and application functionality are validated.

- Renewal, backup, recovery, and rollback procedures exist.

- Monitoring is updated.

- Documentation and governance are synchronized.

# Part 7 - Disaster Recovery

## 1. Disaster Recovery Philosophy

Project Polaris treats PKI disaster recovery as an operational capability rather than a contingency document. A Certification Authority is not production-ready until recovery has been demonstrated using documented procedures and validated artifacts.

- Recovery procedures shall exist before production certificate issuance.

- Backup artifacts shall be validated before production dependence.

- Recovery shall preserve the CA identity and trust chain, not merely restore a server.

- Recovery documentation shall remain accessible independently of CA01 and Active Directory.

- Recovery exercises shall produce lessons learned and required documentation updates.

- Recovery is demonstrated - not assumed.

## 2. PKI Recovery Objectives

- Preserve the Project Polaris trust hierarchy.

- Preserve CA private keys and CA identity.

- Preserve issued-certificate records and revocation state.

- Maintain CRL and AIA continuity.

- Restore certificate issuance and enrollment.

- Keep existing certificates trusted throughout recoverable outages.

- Restore automated backup, monitoring, and operational administration.

- Maintain independent emergency access during recovery.

## 3. Recovery Scenarios

### Scenario 1 - CA01 Service Failure

**Trigger:** AD CS service failure, configuration corruption, failed update, or isolated operating-system issue.

**Required response:** Repair or restore the service while preserving the existing CA identity, database, and private key.

### Scenario 2 - CA01 VM Loss

**Trigger:** VM corruption, storage failure, accidental deletion, or unrecoverable operating-system failure.

**Required response:** Rebuild or restore the VM, recover the CA private key and database, and validate existing and new certificates.

### Scenario 3 - Complete CA01 Acceptance Rebuild

**Trigger:** Intentional destructive validation after automatic backup integration.

**Required response:** Treat the original CA01 as permanently lost and restore from documented recovery artifacts. This is a production acceptance requirement.

### Scenario 4 - ROOTCA01 Recovery

**Trigger:** Loss or corruption of the offline root VM or its operating system.

**Required response:** Rebuild the offline root using its protected private key, CA database, policy files, certificate, CRL, and recovery documentation.

### Scenario 5 - Planned License-Expiration Rebuild

**Trigger:** Evaluation-edition expiration for DC01, ROOTCA01, or CA01.

**Required response:** Perform a scheduled full rebuild using dedicated rebuild SOPs. These are planned lifecycle events, not unexpected failures.

## 4. Dedicated Rebuild SOP Requirements

The following systems require individual rebuild SOPs because each has distinct dependencies, recovery artifacts, and validation requirements:

| System   | Dedicated SOP             | Primary Dependency                                            | Required Proof                                                            |
|----------|---------------------------|---------------------------------------------------------------|---------------------------------------------------------------------------|
| DC01     | DC01 Full Rebuild SOP     | Proxmox and production network                                | AD DS, DNS, authentication, SYSVOL/NETLOGON, backup integration           |
| ROOTCA01 | ROOTCA01 Full Rebuild SOP | Proxmox; network only when controlled publication requires it | Same root identity and key, CA database, root CRL, subordinate records    |
| CA01     | CA01 Full Rebuild SOP     | DC01; ROOTCA01 only when signing/renewal is required          | Same issuing CA identity and key, database, issuance, CRL/AIA, enrollment |

## 5. Required Recovery Artifacts

- CA database.

- CA private key and CA certificate.

- CA configuration and registry exports.

- CAPolicy.inf and approved policy files.

- CRLs, CA certificates, and AIA publication files.

- Certificate-template and Active Directory PKI object inventory.

- VM configuration and approved installation media.

- Project Polaris collector archives and validation logs.

- Protected recovery credentials and key-backup passwords.

- Dedicated rebuild SOPs and recovery checklists.

- Recovery evidence from the most recent validation exercise.

## 6. Dependency-Aware Full-System Recovery Matrix

The authoritative Project Polaris Recovery Kit will be updated during the post-Milestone 3 documentation synchronization. The matrix below records the approved dependency philosophy for that future update.

| Recovery Order | System                                | Dependency / Function                                        | Ordering Note                                                                                                                             |
|----------------|---------------------------------------|--------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| 1              | Physical host and storage             | Hardware foundation                                          | Validate compute, memory, storage, and network interfaces first.                                                                          |
| 2              | Proxmox                               | Virtualization host                                          | Required before hosted infrastructure can be recovered.                                                                                   |
| 3              | Gateway01                             | Home gateway and upstream protection                         | Independent of Firewall01; Gateway01 and Firewall01 may be rebuilt in either order when dependencies permit.                              |
| 4              | Firewall01                            | Production homelab firewall and security boundary            | Independent of Gateway01; Gateway01 and Firewall01 may be rebuilt in either order when dependencies permit.                               |
| 5              | Cyber-FW01                            | Safety/security boundary for the Cyber Range (VMIDs 300-399) | Recover after Firewall01 and before administrative/workload systems so the isolated environment is protected before other systems return. |
| 6              | Admin01                               | Emergency Linux administration                               | Provides an administrative recovery platform before worker and application systems.                                                       |
| 7              | DC01                                  | Production identity and DNS                                  | Required before domain-dependent services and CA01.                                                                                       |
| 8              | ROOTCA01 - when required              | Offline root trust anchor                                    | Not required for every CA01 restore. Required for new subordinate signing, CA renewal, root recovery, or hierarchy validation.            |
| 9              | CA01                                  | Production issuing CA                                        | Restore after DC01; ROOTCA01 only when the specific recovery path requires it.                                                            |
| 10             | Docker01                              | Enterprise application platform                              | Restore after network, administration, and identity foundations.                                                                          |
| 11             | Remaining production systems          | Workers, clients, monitoring, and applications               | Restore according to service dependency and operational importance.                                                                       |
| 12             | Cyber Range (VMIDs 300-399) workloads | Isolated exercise and research systems                       | Restore after Cyber-FW01; persistent infrastructure before disposable workloads.                                                          |

## 7. Recovery Priority Principles

- Recover the host before hosted systems.

- Recover safety and security boundaries before administrative and worker systems.

- Recover administrative capability before broad workload restoration.

- Recover identity and DNS before domain-dependent enterprise services.

- Bring ROOTCA01 online only when the recovery operation requires root-authority activity.

- Recover persistent Cyber Range (VMIDs 300-399) infrastructure before disposable exercise workloads.

- Validate every recovery stage before proceeding to the next stage.

## 8. Recovery Validation

- CA identity and certificate chain are preserved.

- The restored CA uses the original approved private key.

- Previously issued certificates remain trusted.

- CA database and revocation records are intact.

- CRL and AIA publication locations remain available.

- Manual certificate issuance succeeds.

- Automatic enrollment succeeds where configured.

- Backup automation recognizes the rebuilt system.

- Monitoring and audit logging resume.

- Secondary administrative access remains available.

- Documentation accurately reflects the recovered environment.

## 9. Recovery Independence

Disaster recovery shall not depend on the failed service itself. Recovery documentation, credentials, backup repositories, installation media, and emergency administrative paths shall remain available independently of CA01, ROOTCA01, and Active Directory.

## 10. Recovery Testing Cadence

| Level    | Activities                                                     | Purpose                                                          |
|----------|----------------------------------------------------------------|------------------------------------------------------------------|
| Routine  | Backup verification, artifact integrity, log review            | Confirm recovery inputs remain usable                            |
| Periodic | Non-destructive restore, issuance tests, publication checks    | Validate recovery procedures and service continuity              |
| Major    | Complete CA01 rebuild and selected license-expiration rebuilds | Demonstrate end-to-end recoverability and operational acceptance |

## 11. Recovery Documentation and Evidence

- Reason for recovery or rebuild.

- Start and completion times.

- Recovery path selected.

- Artifacts and credentials used.

- Commands or procedures executed.

- Validation results.

- Problems encountered and corrective actions.

- Collector or automation changes required after rebuild.

- Lessons learned.

- Required updates to SOPs, recovery matrices, architecture, governance, and inventories.

## 12. Disaster Recovery Acceptance Criteria

- All required recovery artifacts exist and are validated.

- Dedicated rebuild SOPs exist for DC01, ROOTCA01, and CA01.

- CA01 has been successfully rebuilt from documented recovery artifacts.

- The trust hierarchy remains intact after recovery.

- Previously issued certificates remain trusted.

- New certificate issuance and enrollment succeed.

- CRL and AIA continuity are verified.

- Backup automation and monitoring resume.

- Independent administrative recovery paths remain functional.

- The Project Polaris Recovery Kit is synchronized after Milestone 3.

- Recovery results and lessons learned are documented.

## Approved Future Documentation Actions

| Action                                                                             | Timing                                                      | Classification |
|------------------------------------------------------------------------------------|-------------------------------------------------------------|----------------|
| Add the dependency-aware recovery matrix to the Project Polaris Recovery Kit       | Post-Milestone 3 synchronization                            | Required       |
| Create dedicated rebuild SOPs for DC01, ROOTCA01, and CA01                         | Before each system is accepted for recurring operations     | Required       |
| Standardize all references to Cyber Range (VMIDs 300-399)                          | Final PKI-001 editorial review and later documentation sync | Required       |
| Record the standalone external-assessment platform in future architecture planning | Resource-dependent future milestone                         | Planned        |

# PKI-001 – Project Polaris Public Key Infrastructure Architecture

Working Draft  
Part 8 – Future Evolution

## 1. Future Design Philosophy

Project Polaris is designed to evolve through successive milestones while preserving architectural stability. Future capabilities shall extend the established trust hierarchy rather than require architectural redesign.

## 2. PKI Evolution Roadmap

Future development progresses from Version 1.x core enterprise PKI to expanded authentication, security operations integration, advanced PKI capabilities, and emerging technologies.

## 3. Enterprise Authentication Expansion

Future capabilities may include 802.1X, certificate-based VPN authentication, Windows Hello for Business, smart cards, mutual TLS, client certificates, and certificate-based API authentication.

## 4. Infrastructure Expansion

Additional production services, containers, APIs, and future platforms shall follow the approved PKI integration workflow before receiving production certificates.

## 5. Security Operations Integration

Future integrations may include Wazuh, Windows Event Forwarding, Sysmon, SIEM platforms, detection engineering, threat hunting, and incident response workflows.

## 6. Cyber Range (VMIDs 300–399)

The Cyber Range (VMIDs 300–399) will operate an entirely independent PKI with its own Active Directory forest, Root CA, Issuing CA, templates, and administrative authority. Cross-boundary trust shall exist only for documented educational objectives.

## 7. Artificial Intelligence and Automation

Future AI systems (VMIDs 400–499) may assist with certificate lifecycle reporting, renewal recommendations, compliance reporting, documentation synchronization, and operational analytics while respecting the Operational Independence Principle.

## 8. External Security Assessment

A standalone trusted Kali Linux laptop will serve as an external assessment platform. It is not permanently connected to the production network, is not part of the production trust boundary, and is not part of the Cyber Range (VMIDs 300–399). It simulates an external adversary during approved assessments without disruption to operations. Its purpose is to support penetration testing, red-team exercises, purple-team validation, hardening verification, detection engineering, and SOC workflow validation while preserving realistic business operations.

## 9. Cryptographic Evolution

Future enhancements may include HSMs, TPM-backed keys, hardware-backed credentials, post-quantum cryptography, certificate transparency mechanisms, and modern certificate management protocols.

## 10. Long-Term Governance

Future security controls shall continue documenting: what the control does, why it improves security, what attacks it mitigates, and the operational trade-offs it introduces. Documentation remains the authoritative engineering reference.

## 11. Architecture Stability

The separation of architecture, implementation, operations, and governance allows hardware upgrades, rebuilds, service expansion, and template additions without redesigning the trust architecture.

## 12. Version 1.0 Completion Criteria

PKI-001 Version 1.0 is complete when all architectural sections are approved, required engineering updates are incorporated, documentation is synchronized, terminology is standardized, supporting SOPs are identified, and a final editorial review has been completed.

## Engineering Observation

Project Polaris intentionally designs beyond Version 1.0 so future enterprise capabilities can be implemented by extending the established architecture rather than replacing it. Future implementation detail will reside within system-specific SOPs and operational runbooks rather than a separate PKI implementation document.

### Part 4 – Operational Design

This section defines how the Project Polaris PKI will be administered, monitored, validated, and maintained throughout its lifecycle.

#### Operational Philosophy

PKI is treated as a long-lived enterprise service. Every operation must be repeatable, recoverable, auditable, documented, validated, and performed using least privilege.

#### Certificate Lifecycle

- Requirement Identified

- Template Selection

- Enrollment Request

- Approval (if required)

- Issuance

- Deployment

- Operational Validation

- Monitoring

- Renewal

- Retirement

- Revocation (if required)

#### Enrollment Strategy

Automatic enrollment is reserved for trusted Active Directory systems after staged validation. Infrastructure services use controlled manual enrollment. Cyber-range systems remain excluded from the production PKI.

#### Monitoring

- CA health

- Certificate expirations

- Failed enrollments

- CRL/AIA publication

- Backup success

- Audit logs

- Template status

- Recovery validation

#### Operational Independence

The PKI shall never become a dependency that prevents its own recovery.  
  
Accordingly, all Project Polaris infrastructure systems shall maintain appropriate independent administrative capabilities where operationally applicable. These capabilities exist solely to support maintenance, disaster recovery, and restoration of critical infrastructure services.  
  
Examples include:  
• Secondary administrative access methods.  
• Local authentication.  
• Local administrative access.  
• Emergency administrative credentials maintained in accordance with Project Polaris governance.  
• Recovery documentation that remains accessible independently of CA01 and Active Directory.  
  
The specific implementation of these capabilities may vary by platform; however, every critical system shall retain a documented recovery path that does not depend upon the availability of the Project Polaris PKI.

#### Operational Acceptance Criteria

- Certificate issuance validated

- Auto-enrollment validated

- Manual enrollment validated

- CRLs current

- AIA reachable

- Backups successful

- Restore procedures validated

- Monitoring operational

- Documentation synchronized

- Governance updated

# PKI-001 – Project Polaris Public Key Infrastructure Architecture

Working Draft  
Combined Part 5 – Security Architecture

## Part 5 – Security Architecture

### Security Philosophy

Project Polaris classifies PKI as Tier 0 infrastructure. Security priorities are: protection of the trust hierarchy, recoverability, operational continuity, least privilege, defense in depth, auditability, and maintainability.

### Trust Anchor Protection

ROOTCA01 remains offline except during authorized maintenance, is not domain joined, has no routine network connectivity, and never issues end-entity certificates. CA01 is domain joined, hardened, monitored, backed up, and performs daily certificate issuance.

### Administrative Security Model

Logical roles include Enterprise Administrator, PKI Administrator, Certificate Manager, Certificate Auditor, Backup Administrator, and Recovery Administrator. Duties may initially be combined but remain logically separated.

### Private Key Protection

Root and issuing CA private keys are protected through approved backup and recovery procedures. Non-exportable keys are preferred unless interoperability requires export.

### Administrative Workstations

PKI administration is performed only from approved administrative workstations, initially Admin-WS.

### Auditing and Logging

Audit certificate issuance, revocation, template changes, administrative access, configuration changes, backup, restore, and recovery validation.

### Cryptographic Standards

Version 1.0 adopts RSA-4096/SHA-256 for Certification Authorities and RSA-2048 minimum/SHA-256 for issued certificates.

### Security Change Control

Significant PKI changes require verified backups, documented recovery procedures, risk review, validation, documentation updates, and rollback capability.

### Incident Response

Documented containment, investigation, recovery, validation, and lessons learned are required for private key compromise, unauthorized issuance, CA compromise, template errors, and related incidents.

### Security Validation

Validate permissions, trust hierarchy, issuance, CRL/AIA publication, backup integrity, restore capability, audit logging, and recovery procedures.

### Security Acceptance Criteria

The PKI is operational only when the trust hierarchy, key protection, monitoring, backup, recovery validation, documentation, and governance are all verified.

### Engineering Notes (Future Project-Wide Standard)

Every future security or hardening decision should document: 1) What the control does; 2) Why it improves security; 3) What attacks it mitigates; 4) Operational trade-offs. This educational model will become a Project Polaris documentation standard.
