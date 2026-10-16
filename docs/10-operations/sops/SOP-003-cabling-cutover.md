# Project Polaris
# Standard Operating Procedure
# Production Network Cutover

**Document ID:** SOP-NET-001  
**Version:** 0.1 (Draft)  
**Status:** In Development  
**Author:** Jesse Breedlove  
**Project:** Project Polaris

---

# 1. Objective

Transition the home production network from the current Deco router-based architecture to the Project Polaris Gateway01 architecture while maintaining the ability to quickly restore service if any portion of the cutover is unsuccessful.

This maintenance window includes only the tasks required to place Gateway01 into production, transition the Deco mesh into Access Point mode, enable production DHCP and DNS services, and verify that all critical network functionality has been restored.

---

# 2. Scope

## Included

- Transition production routing to Gateway01
- Reconfigure physical network cabling
- Configure the Deco mesh for Access Point mode
- Transfer DHCP services to Gateway01
- Transfer DNS services to Pi-hole
- Validate production connectivity
- Validate homelab connectivity
- Verify critical services
- Complete post-cutover validation

## Excluded

- Docker01 dual-homing
- Uptime Kuma monitoring changes
- Documentation updates
- Infrastructure improvements
- General maintenance
- Metadata cleanup

These activities will be completed after the maintenance window has successfully concluded.

---

# 3. Preconditions

The maintenance window may begin only after confirming:

- Current production network is operating normally.
- Gateway01 has been fully staged and validated.
- Pi-hole has been fully staged and validated.
- Current configuration backups exist.
- Required VM snapshots exist.
- Administrative access to all required systems has been verified.
- Physical access to all required equipment is available.

If any precondition is not satisfied, postpone the maintenance window.

---

# 4. Maintenance Objectives

The maintenance window is complete only after:

- Gateway01 is the production Internet gateway.
- Deco mesh operates in Access Point mode.
- Production DHCP is operational.
- Production DNS is operational.
- Internet connectivity has been restored.
- Homelab connectivity has been restored.
- Critical services are operational.
- All validation checks have passed.

---

# 5. Success Criteria

The cutover is successful when:

- All maintenance objectives are complete.
- No critical validation failures remain.
- No rollback conditions exist.
- Internet access is restored.
- Homelab services are reachable.
- DNS resolution operates correctly.
- Gateway01 is functioning as the production router.

---

# 6. Rollback Criteria

Immediately execute the rollback procedure if:

- Internet connectivity cannot be restored.
- Gateway01 cannot obtain a functional WAN connection.
- DHCP cannot be restored.
- DNS cannot be restored.
- Multiple critical validation steps fail.
- Recovery procedures for the current logical operation are unsuccessful.

Do not continue after a rollback condition has been identified.

---

# Section 2 – Preparation

## Objective

Verify that all systems, backups, documentation, and recovery resources are available before beginning the production network cutover.

---

## Verify Current Network Health

| Item | Verify | Location | Complete |
|------|--------|----------|:--------:|
| Internet | Internet access functioning | Client PC | ☐ |
| Kitchen Deco | Online | Kitchen | ☐ |
| Wireless Clients | Connected normally | Production Network | ☐ |
| Homelab | Reachable | Office | ☐ |
| Admin01 | Reachable | Office | ☐ |
| Gateway01 | Powered on | Proxmox | ☐ |
| Pi-hole | Powered on | Proxmox | ☐ |

### Recovery

Resolve any existing network issues before beginning the maintenance window.

### Decision

PASS → Continue

FAIL → Resolve issues before continuing

---

## Verify Recovery Resources

| Item | Verify | Location | Complete |
|------|--------|----------|:--------:|
| Gateway01 Backup | Latest backup exists | Environment Reference | ☐ |
| Pi-hole Backup | Latest backup exists | Environment Reference | ☐ |
| Proxmox VM Backup | Latest backup exists | Environment Reference | ☐ |
| Proxmox Host Backup | Latest backup exists | Environment Reference | ☐ |
| Switch01 Backup | Latest backup exists | Environment Reference | ☐ |
| NanoStation Backup | Latest backup exists | Environment Reference | ☐ |
| VM Snapshots | Required snapshots exist | Proxmox | ☐ |
| Documentation | Accessible | Documentation Repository | ☐ |

### Recovery

Create any missing backup or snapshot.

### Decision

PASS → Continue

FAIL → Complete missing backups before continuing

---

## Verify Administrative Access

| Item | Verify | Location | Complete |
|------|--------|----------|:--------:|
| Proxmox | Login successful | Environment Reference | ☐ |
| Gateway01 | Login successful | Environment Reference | ☐ |
| Pi-hole | Login successful | Environment Reference | ☐ |
| Switch01 | Login successful | Environment Reference | ☐ |
| NanoStation Station | Login successful | Environment Reference | ☐ |
| NanoStation AP | Login successful | Environment Reference | ☐ |
| Kitchen Deco | Login successful | Environment Reference | ☐ |
| Office Deco | Login successful | Environment Reference | ☐ |
| Vaultwarden | Accessible | Environment Reference | ☐ |

### Recovery

Restore administrative access.

### Decision

PASS → Continue

FAIL → Resolve access issues

---

## Verify Physical Readiness

| Item | Verify | Location | Complete |
|------|--------|----------|:--------:|
| Ethernet Cables | Available | Office | ☐ |
| Admin Workstation | Available | Office | ☐ |
| UPS | Operating normally | Office | ☐ |
| ISP Router | Accessible | Kitchen | ☐ |
| Kitchen Equipment | Accessible | Kitchen | ☐ |
| Office Equipment | Accessible | Office | ☐ |

### Recovery

Gather any missing equipment.

### Decision

PASS → Continue

FAIL → Obtain missing equipment

---

## Final Preparation

| Item | Verify | Location | Complete |
|------|--------|----------|:--------:|
| Required Browser Tabs | Open | Admin01 | ☐ |
| Gateway01 Console | Open | Proxmox | ☐ |
| Pi-hole Admin | Open | Browser | ☐ |
| Gateway01 Web UI | Open | Browser | ☐ |
| Documentation | Available | Local Copy | ☐ |

### Recovery

Resolve any remaining preparation issues.

### Decision

PASS → Begin Section 3

FAIL → Resolve Preparation Issues

---

# Section 3 – Cutover Execution

## Execution Sequence

1. Verify Preparation Complete
2. Reconfigure Physical Network Cabling
3. Validate Gateway01 WAN Connectivity
4. Verify Internet Connectivity
5. Configure Deco Mesh for Access Point Mode
6. Validate Client Connectivity
7. Transfer DHCP Services to Gateway01
8. Validate DHCP Operation
9. Transfer DNS Services to Pi-hole
10. Validate DNS Resolution
11. Verify Homelab Connectivity
12. Verify Critical Infrastructure
13. Final Production Validation
14. Create Production Backups
15. Close Maintenance Window

---

# Reconfigure Physical Network Cabling

## Objective

Reconfigure the physical Ethernet connections so Internet traffic crosses the NanoStation wireless bridge, enters Gateway01 through Proxmox Port 4 (Gateway01 WAN), exits Gateway01 through Proxmox Port 3 (Gateway01 LAN), and then reaches the Office Deco and Switch01.

| Step | Procedure | Expected Result | Location | Complete |
|------|-----------|-----------------|----------|:--------:|
| 1 | Verify all network equipment is powered on. | All devices operational | Kitchen / Office | ☐ |
| 2 | Disconnect the Ethernet cable from the ISP Router to the Kitchen Deco. | Cable removed | Kitchen | ☐ |
| 3 | Disconnect the NanoStation Station Ethernet cable from the Kitchen Deco. | Cable removed | Kitchen | ☐ |
| 4 | Connect the ISP Router directly to the NanoStation Station. | Link LED illuminated | Kitchen | ☐ |
| 5 | Disconnect the NanoStation AP Ethernet cable from its current downstream connection. | Cable removed | Office | ☐ |
| 6 | Connect the NanoStation AP Ethernet cable to Proxmox Port 4 (Gateway01 WAN). | Link LED illuminated | Office | ☐ |
| 7 | Connect Proxmox Port 3 (Gateway01 LAN) to the Office Deco WAN port. | Link LED illuminated | Office | ☐ |
| 8 | Verify the Office Deco remains connected to Switch01. | Switch connectivity maintained | Office | ☐ |
| 9 | Verify all affected Ethernet cables are fully seated. | All cables secure | Kitchen / Office | ☐ |
| 10 | Verify link/activity LEDs are present on all affected interfaces. | Physical connectivity established | Kitchen / Office | ☐ |

### Recovery

1. Restore the original cabling.
2. Verify the original production network is operational.
3. Stop the maintenance window until the physical issue has been corrected.

### Decision

PASS → Proceed to **Validate Gateway01 WAN Connectivity**

FAIL → Execute Recovery Procedure
