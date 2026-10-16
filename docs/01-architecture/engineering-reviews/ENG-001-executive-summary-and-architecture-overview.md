# ENG-001 Part 1 - Production Framework Inventory & Engineering Reference

## Document Information

| Document ID | ENG-001                                                |
| ----------- | ------------------------------------------------------ |
| Title       | Production Framework Inventory & Engineering Reference |
| Version     | 1.0                                                    |
| Status      | Production Baseline                                    |
| Scope       | Project Polaris Configuration Backup Framework         |

## Executive Summary

This document is the authoritative engineering reference for the Project Polaris Configuration Backup Framework Version 1.0. It documents the production architecture, engineering intent, and long-term maintenance guidance rather than operational procedures.

## Framework Purpose

The framework provides a registry-driven, validated backup system for infrastructure configuration management. Its design emphasizes deterministic execution, shared services, explicit interfaces, validation before promotion, preservation of troubleshooting evidence, and long-term maintainability.

## Design Philosophy

- Single-responsibility components.
- Registry-driven configuration.
- Explicit interfaces over hidden dependencies.
- Shared services instead of duplicated logic.
- Validation before promotion.
- Failure preservation for troubleshooting.
- Incremental engineering with regression validation.

## Production Architecture Overview

A single orchestrator coordinates nine production collectors through shared registries, a common execution pipeline, lifecycle state management, logging, manifest verification, recovery handling, and specialized shared engines for firewall and manual-export collectors.

## Supported Production Collectors

| Collector    | Primary Responsibility    |
| ------------ | ------------------------- |
| Proxmox      | Host configuration        |
| pfSense      | Primary firewall          |
| OPNsense     | Cyber-range firewall      |
| Switch01     | Managed switch            |
| NANO-AP      | Bridge AP                 |
| NANO-STATION | Bridge station            |
| Docker01     | Container services        |
| Admin01      | Linux admin host          |
| Admin-WS     | Windows admin workstation |

## Version 1.0 Baseline Statement

This engineering reference documents the validated production baseline established after fourteen controlled refactoring waves and the successful completion of Phase 3.5. It serves as the architectural foundation for all future enhancements.

# ENG-001 Part 6 - Engineering Maintenance Guidance & Version 1.0 Baseline Declaration

## 1\. Long-Term Engineering Maintenance Guidance

The Version 1.0 framework is intended to evolve through controlled, incremental changes. Engineering effort should prioritize extending existing shared services before introducing new abstractions. Every architectural change should be validated independently and preserve a known-good rollback point.

## 2\. Engineering Principles

- Protect production stability before pursuing architectural elegance.
- Favor explicit interfaces over implicit dependencies.
- Keep reusable behavior in shared libraries and device-specific behavior in collectors.
- Validate every meaningful change before proceeding to the next.
- Preserve troubleshooting evidence whenever failures occur.
- Document architectural intent so future maintenance does not require reverse engineering.

## 3\. Operational Assumptions

This framework assumes a controlled homelab environment with scheduled execution, centralized archival storage, registry-driven collector discovery, and validation prior to promotion. Changes that alter these assumptions should undergo an architectural review.

## 4\. Future Roadmap Guidance

| Area              | Recommended Direction                                           |
| ----------------- | --------------------------------------------------------------- |
| New Collectors    | Integrate using the existing registries and execution pipeline. |
| Shared Features   | Extend existing shared libraries before creating new ones.      |
| Framework Changes | Require engineering review and regression validation.           |
| Documentation     | Update ENG-series documents alongside architectural changes.    |
| Versioning        | Treat Version 1.0 as the permanent reference baseline.          |

## 5\. Version 1.0 Production Baseline Declaration

The Project Polaris Configuration Backup Framework Version 1.0 is declared the authoritative production baseline following the successful completion of fourteen validated refactoring waves, production housekeeping, and the engineering review conducted during Phase 3.6. The architecture documented throughout ENG-001 shall serve as the reference point for future maintenance and enhancement.

## 6\. Closing Statement

ENG-001 completes the initial engineering reference for the Project Polaris Configuration Backup Framework. Together, its six parts document the framework's architecture, production inventory, shared services, collector design, dependency model, maintenance guidance, and Version 1.0 baseline. Future engineering work should build upon this reference while preserving the principles that produced the validated production implementation.

# ENG-001 Part 5 - Dependency Architecture & Extension Strategy

This section documents the dependency relationships within the production framework and defines the approved extension strategy for future development. Its purpose is to help future engineers understand where functionality belongs before modifying or extending the framework.

## 1\. Architectural Dependency Hierarchy

The framework follows a layered dependency model. Higher layers coordinate execution while lower layers provide reusable services consumed by collectors.

- Layer 1 - Orchestrator (polaris-backup)
- Layer 2 - Registries and Lifecycle Services
- Layer 3 - Shared Libraries (polaris-common.sh, polaris-firewall-collector.sh)
- Layer 4 - Verification Framework (verify-manifest.sh)
- Layer 5 - Production Collectors
- Layer 6 - Generated Artifacts, Logs, and Retention Targets

## 2\. Dependency Rules

- Collectors shall not depend on one another.
- Reusable behavior belongs in shared libraries rather than collector wrappers.
- Registries are the authoritative source for discovery and configuration.
- The orchestrator coordinates execution but does not implement device-specific collection logic.
- Verification occurs before promotion to production storage.
- Recovery services preserve troubleshooting evidence before cleanup.

## 3\. Extension Decision Matrix

| Scenario                    | Preferred Action                                          | Reason                                          |
| --------------------------- | --------------------------------------------------------- | ----------------------------------------------- |
| New SSH-based device        | Create a collector wrapper using existing shared services | Maintains consistency and minimizes duplication |
| New firewall platform       | Extend the shared firewall engine                         | Keeps platform logic centralized                |
| New manual-export device    | Register with the Manual Export Registry                  | Reuses validated workflow                       |
| Reusable functionality      | Add to a shared library                                   | Avoids duplicate implementations                |
| Collector-specific behavior | Keep inside the collector wrapper                         | Preserves single responsibility                 |

## 4\. Engineering Principles for Future Development

Future enhancements should preserve the architecture established during the fourteen-wave refactoring effort. New functionality should integrate with existing services whenever practical, favor explicit interfaces over hidden dependencies, and be validated through incremental implementation rather than large-scale rewrites.

## 5\. Version 1.0 Architectural Boundaries

The Version 1.0 production baseline establishes the orchestrator, shared libraries, registries, lifecycle engine, verification framework, and nine production collectors as the supported architecture. Future versions should treat these components as stable extension points unless a documented architectural review justifies a change.

# ENG-001 Part 4 - Production Collector Engineering Reference

This section provides an engineering profile for each production collector. The intent is to document architectural responsibilities, dependencies, shared services, produced artifacts, and extension guidance.

## Proxmox

| Primary Responsibility | Collects Proxmox VE host configuration.                                                  |
| ---------------------- | ---------------------------------------------------------------------------------------- |
| Collection Method      | SSH                                                                                      |
| Shared Services        | Collector Registry, Execution Pipeline, Lifecycle Engine, Logging, Manifest              |
| Primary Artifact       | Host configuration archive                                                               |
| Engineering Guidance   | Reference implementation for SSH-based infrastructure collectors.                        |
| Lifecycle Role         | Discovered by the Collector Registry and executed through the common execution pipeline. |

## pfSense

| Primary Responsibility | Collects primary firewall configuration.                                                 |
| ---------------------- | ---------------------------------------------------------------------------------------- |
| Collection Method      | SSH                                                                                      |
| Shared Services        | Firewall Engine, Lifecycle, Logging, Manifest                                            |
| Primary Artifact       | Firewall configuration archive                                                           |
| Engineering Guidance   | Keep platform-specific logic in the shared firewall engine.                              |
| Lifecycle Role         | Discovered by the Collector Registry and executed through the common execution pipeline. |

## OPNsense

| Primary Responsibility | Collects cyber-range firewall configuration.                                             |
| ---------------------- | ---------------------------------------------------------------------------------------- |
| Collection Method      | SSH                                                                                      |
| Shared Services        | Firewall Engine, Lifecycle, Logging, Manifest                                            |
| Primary Artifact       | Firewall configuration archive                                                           |
| Engineering Guidance   | Wrapper should remain thin.                                                              |
| Lifecycle Role         | Discovered by the Collector Registry and executed through the common execution pipeline. |

## Switch01

| Primary Responsibility | Processes manual switch export.                                                          |
| ---------------------- | ---------------------------------------------------------------------------------------- |
| Collection Method      | Manual export                                                                            |
| Shared Services        | Manual Export Registry, Lifecycle, Logging                                               |
| Primary Artifact       | Switch configuration archive                                                             |
| Engineering Guidance   | Register new manual-export devices rather than duplicating code.                         |
| Lifecycle Role         | Discovered by the Collector Registry and executed through the common execution pipeline. |

## NANO-AP

| Primary Responsibility | Processes NanoStation AP export.                                                         |
| ---------------------- | ---------------------------------------------------------------------------------------- |
| Collection Method      | Manual export                                                                            |
| Shared Services        | Manual Export Registry, Lifecycle, Logging                                               |
| Primary Artifact       | Bridge AP archive                                                                        |
| Engineering Guidance   | Uses shared manual-export engine.                                                        |
| Lifecycle Role         | Discovered by the Collector Registry and executed through the common execution pipeline. |

## NANO-STATION

| Primary Responsibility | Processes NanoStation Station export.                                                    |
| ---------------------- | ---------------------------------------------------------------------------------------- |
| Collection Method      | Manual export                                                                            |
| Shared Services        | Manual Export Registry, Lifecycle, Logging                                               |
| Primary Artifact       | Bridge Station archive                                                                   |
| Engineering Guidance   | Uses shared manual-export engine.                                                        |
| Lifecycle Role         | Discovered by the Collector Registry and executed through the common execution pipeline. |

## Docker01

| Primary Responsibility | Collects Docker host configuration.                                                      |
| ---------------------- | ---------------------------------------------------------------------------------------- |
| Collection Method      | SSH                                                                                      |
| Shared Services        | Common Library, Lifecycle, Logging, Manifest                                             |
| Primary Artifact       | Service configuration archive                                                            |
| Engineering Guidance   | Container-specific enhancements belong in collector wrapper.                             |
| Lifecycle Role         | Discovered by the Collector Registry and executed through the common execution pipeline. |

## Admin01

| Primary Responsibility | Collects Linux administration host configuration.                                        |
| ---------------------- | ---------------------------------------------------------------------------------------- |
| Collection Method      | SSH                                                                                      |
| Shared Services        | Common Library, Lifecycle, Logging                                                       |
| Primary Artifact       | Administrative host archive                                                              |
| Engineering Guidance   | Administrative endpoint.                                                                 |
| Lifecycle Role         | Discovered by the Collector Registry and executed through the common execution pipeline. |

## Admin-WS

| Primary Responsibility | Collects Windows administration workstation configuration.                               |
| ---------------------- | ---------------------------------------------------------------------------------------- |
| Collection Method      | SSH                                                                                      |
| Shared Services        | Common Library, Lifecycle, Logging                                                       |
| Primary Artifact       | Administrative workstation archive                                                       |
| Engineering Guidance   | Windows administrative endpoint.                                                         |
| Lifecycle Role         | Discovered by the Collector Registry and executed through the common execution pipeline. |

## Collector Family Summary

The nine collectors intentionally fall into three architectural families: SSH-based infrastructure collectors (Proxmox, Docker01, Admin01, Admin-WS), shared firewall collectors (pfSense and OPNsense), and shared manual-export collectors (Switch01, NANO-AP, NANO-STATION). Each family consumes common framework services while keeping device-specific logic isolated.

## Extension Guidance

Future collectors should first determine whether an existing family can be extended. New SSH collectors should reuse the common framework services, new firewall platforms should extend the shared firewall engine, and new manual-export devices should register with the Manual Export Registry. Creating a new framework service should be reserved for genuinely new collection patterns.

# ENG-001 Part 3 - Framework Services & Shared Architecture

This section documents the shared framework services that collectively form the Project Polaris Configuration Backup Framework. Rather than describing individual scripts, it explains the architectural responsibilities of the reusable services and how they interact.

## Collector Registry

| Purpose               | Maintains the authoritative list of production collectors and their metadata.              |
| --------------------- | ------------------------------------------------------------------------------------------ |
| Framework Interaction | Consumed by the orchestrator execution pipeline to discover and execute collectors.        |
| Engineering Guidance  | Future collectors should be registered here instead of introducing custom execution logic. |
| Design Principle      | Centralize reusable behavior while preserving explicit interfaces.                         |

## Execution Pipeline

| Purpose               | Provides a single standardized execution path for all collectors.                 |
| --------------------- | --------------------------------------------------------------------------------- |
| Framework Interaction | Coordinates timing, invocation, lifecycle transitions, validation, and reporting. |
| Engineering Guidance  | Behavior should remain collector-agnostic.                                        |
| Design Principle      | Centralize reusable behavior while preserving explicit interfaces.                |

## Lifecycle State Engine

| Purpose               | Normalizes collector outcomes into consistent framework states.                     |
| --------------------- | ----------------------------------------------------------------------------------- |
| Framework Interaction | Ensures deterministic handling of success, no-change, failure, and internal errors. |
| Engineering Guidance  | All new collector outcomes should flow through this engine.                         |
| Design Principle      | Centralize reusable behavior while preserving explicit interfaces.                  |

## Manual Export Registry

| Purpose               | Centralizes configuration for collectors that rely on manually exported configuration files. |
| --------------------- | -------------------------------------------------------------------------------------------- |
| Framework Interaction | Used by Switch01, NANO-AP, and NANO-STATION.                                                 |
| Engineering Guidance  | Additional manual-export collectors should register here rather than duplicating logic.      |
| Design Principle      | Centralize reusable behavior while preserving explicit interfaces.                           |

## Firewall Collector Engine

| Purpose               | Implements the shared SSH-based retrieval and processing workflow for firewall platforms. |
| --------------------- | ----------------------------------------------------------------------------------------- |
| Framework Interaction | Used by pfSense and OPNsense wrappers.                                                    |
| Engineering Guidance  | Firewall-specific enhancements should be implemented here before modifying wrappers.      |
| Design Principle      | Centralize reusable behavior while preserving explicit interfaces.                        |

## Logging Framework

| Purpose               | Provides standardized operator messaging and persistent logging.   |
| --------------------- | ------------------------------------------------------------------ |
| Framework Interaction | Separates console output from detailed diagnostic logs.            |
| Engineering Guidance  | Maintain consistent reporting across all collectors.               |
| Design Principle      | Centralize reusable behavior while preserving explicit interfaces. |

## Recovery Framework

| Purpose               | Detects abandoned workspaces, preserves evidence, recreates clean working directories, and allows orchestration to continue. |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Framework Interaction | Protects troubleshooting artifacts while minimizing operator intervention.                                                   |
| Engineering Guidance  | Future recovery behaviors should extend this service.                                                                        |
| Design Principle      | Centralize reusable behavior while preserving explicit interfaces.                                                           |

## Manifest Framework

| Purpose               | Validates archive integrity prior to promotion.                                            |
| --------------------- | ------------------------------------------------------------------------------------------ |
| Framework Interaction | Ensures production artifacts are internally consistent before retention and NAS promotion. |
| Engineering Guidance  | Acts as the authoritative integrity validation mechanism.                                  |
| Design Principle      | Centralize reusable behavior while preserving explicit interfaces.                         |

## Service Relationship Summary

The orchestrator serves as the entry point to the framework. It consumes the Collector Registry to identify active collectors, executes them through the Execution Pipeline, records outcomes in the Lifecycle State Engine, relies on the Logging Framework for operator visibility, invokes the Recovery Framework when interrupted workspaces are detected, and validates output through the Manifest Framework. Specialized collector families leverage the Manual Export Registry and Firewall Collector Engine to eliminate duplicated implementation.

## Engineering Observations

The refactoring completed during Phase 3.5 transformed the backup solution from a collection of independent scripts into a service-oriented framework. Shared services now own reusable behavior while collectors focus only on device-specific collection logic. This separation reduces maintenance effort, simplifies future expansion, and limits the introduction of technical debt.

# ENG-001 Part 2 - Production File Inventory

This section inventories every production component that constitutes the Version 1.0 backup framework. Each entry identifies its architectural responsibility, primary interfaces, dependencies, and maintenance guidance.

## config-backup/bin/polaris-backup

| Component            | Primary orchestrator                                                                                                                                |
| -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| Purpose              | Coordinates the complete backup workflow, loads registries, executes collectors, manages lifecycle state, recovery, retention, and final reporting. |
| Dependencies         | Uses: polaris-common.sh, polaris-firewall-collector.sh, verify-manifest.sh, all collectors.                                                         |
| Public Interface     | Script entry point / exported framework functions                                                                                                   |
| Maintenance Guidance | Modify only when orchestration behavior changes.                                                                                                    |

## config-backup/lib/polaris-common.sh

| Component            | Shared framework library                                                                                                                           |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Purpose              | Provides common helper functions, metadata generation, manual-export engine, logging helpers, staging management, and reusable framework services. |
| Dependencies         | Used by: all collectors and orchestrator.                                                                                                          |
| Public Interface     | Script entry point / exported framework functions                                                                                                  |
| Maintenance Guidance | Preferred location for new reusable logic.                                                                                                         |

## config-backup/lib/polaris-firewall-collector.sh

| Component            | Shared firewall engine                                                            |
| -------------------- | --------------------------------------------------------------------------------- |
| Purpose              | Implements common firewall retrieval and processing used by pfSense and OPNsense. |
| Dependencies         | Used by: pfsense.sh, opnsense.sh.                                                 |
| Public Interface     | Script entry point / exported framework functions                                 |
| Maintenance Guidance | Extend here before modifying individual firewall collectors.                      |

## framework/verify-manifest.sh

| Component            | Verification utility                                        |
| -------------------- | ----------------------------------------------------------- |
| Purpose              | Validates archive manifests and integrity before promotion. |
| Dependencies         | Used by: orchestrator.                                      |
| Public Interface     | Script entry point / exported framework functions           |
| Maintenance Guidance | Treat as authoritative verification implementation.         |

## Production Collector Inventory

| Collector    | Collection Method | Shared Services        | Outputs                              | Notes                       |
| ------------ | ----------------- | ---------------------- | ------------------------------------ | --------------------------- |
| Proxmox      | SSH               | Common library         | Host config archive                  | Reference implementation    |
| pfSense      | SSH               | Firewall engine        | Firewall config                      | Shared firewall engine      |
| OPNsense     | SSH               | Firewall engine        | Firewall config                      | Shared firewall engine      |
| Switch01     | Manual export     | Manual-export registry | Switch config                        | Shared manual-export engine |
| NANO-AP      | Manual export     | Manual-export registry | Bridge config                        | Shared manual-export engine |
| NANO-STATION | Manual export     | Manual-export registry | Bridge config                        | Shared manual-export engine |
| Docker01     | SSH               | Common library         | Service configuration                | Container host              |
| Admin01      | SSH               | Common library         | Linux host configuration             | Administrative endpoint     |
| Admin-WS     | SSH               | Common library         | Windows administration configuration | Administrative workstation  |

## Engineering Notes

All production functionality is intentionally concentrated into the orchestrator, two shared libraries, one verification utility, and nine active collectors. Future collectors should integrate with existing registries and shared services before introducing new framework components. This minimizes technical debt and preserves the architectural consistency established during the fourteen-wave refactoring effort.