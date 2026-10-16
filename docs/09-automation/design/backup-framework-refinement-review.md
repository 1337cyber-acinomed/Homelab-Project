<!-- Converted from Word document: Project-Polaris-Backup-Framework-Refinement-Review-Consolidated.docx -->

**Purpose:** This document consolidates all approved Phase 3 review findings into a single implementation review package. It is intended only as a maintenance/refinement document. No production code changes are made during this phase.

**Implementation Methodology**

- Review all recommendations before implementation.

- Prioritize by Priority and Risk.

- Implement one high-risk change at a time with full validation.

- Group low-risk refinements where practical.

- Retain known-good originals until validation is complete.

PROJECT POLARIS

Phase 3.2  
Shared Library Review

Actionable refinement findings for polaris-common.sh and duplicated framework services

Prepared for the Phase 3 implementation review

# 1. Scope and Review Result

This review is intentionally limited to changes that may improve the shared library or reduce duplicated framework services. It does not inventory components that require no action, redesign the backup architecture, or introduce new product features.

Overall result: No P1 correctness or security defect was identified in the shared-library layer. The principal opportunities are API cleanup, clearer logging behavior, and selective consolidation of highly duplicated infrastructure code.

# 2. Recommendation Summary

# Finding 3.3.1 - Control Local Archive Growth

## What needs to change

Apply an explicit retention or cleanup policy to /staging/archive, or remove each local compressed archive after its NAS copy has been validated and promoted when the validated directory is the approved local recovery copy.

## Purpose of the change

Prevent the local backup host from retaining two complete copies of every successful backup indefinitely: the expanded validated directory and the compressed archive workspace.

## Why it needs to change

The orchestrator creates archives under /staging/archive/\<collector\>/\<backup-name\>, but the current retention functions operate only on /staging/validated and /staging/quarantine. No archive-retention path is present. Scheduled execution would therefore allow compressed archives to grow without limit even while validated backup retention appears to be working.

## Affected area

bin/polaris-backup: \_process_collector_lifecycle(), \_create_local_archive(), retention functions

## Implementation boundary

The approved implementation should first decide which local copy is authoritative after NAS promotion. The change must preserve the existing recovery objective and be validated with disk-usage checks before and after multiple runs.

# Finding 3.3.2 - Run Retention Independently of New Backup Promotion

## What needs to change

Move scheduled retention execution out of the successful new-or-changed lifecycle branch so local retention can run once per orchestrator execution even when a collector reports no change, a collector fails, or NAS01 is unavailable. NAS retention should run only when NAS01 is available, but local retention should not depend on NAS success.

## Purpose of the change

Ensure retention remains an operational maintenance function rather than a side effect of successfully producing and promoting a new archive.

## Why it needs to change

Both validated and quarantine retention are currently called only after a NAS copy is validated and promoted. If all collectors report no change, or NAS01 is unavailable, retention does not run. This can leave expired local validated backups, quarantine data, and troubleshooting evidence in place indefinitely during long periods without configuration changes or during a NAS outage.

## Affected area

bin/polaris-backup: main(), \_process_collector_lifecycle(), \_apply_validated_retention(), \_apply_quarantine_retention()

## Implementation boundary

Retention should remain collector-aware and should preserve the existing distinction between local and NAS retention periods. Failure to remove one expired item must be reported without deleting newer backups.

# Finding 3.3.3 - Complete Startup Validation and Workspace Preparation for Every Collector

## What needs to change

Update prerequisite validation and local directory preparation so all active collectors are checked and all current, validated, quarantine, and troubleshooting paths are handled consistently before collection begins. The current logic must include Docker01, Admin01, and Admin-WS as first-class entries rather than relying on their wrappers or collectors to discover missing paths later.

## Purpose of the change

Fail early and consistently before a partial scheduled run begins, and detect stale workspaces from interrupted executions for every collector.

## Why it needs to change

The current upfront environment validation checks only part of the active collector set, while \_prepare_local_directories() explicitly prepares and checks only the earlier collectors. Later wrappers do their own readability checks, and later collectors may create their own staging roots, but this means a missing collector or stale workspace can be discovered only after several earlier collectors have already completed. That is less predictable for unattended execution and makes startup validation incomplete.

## Affected area

bin/polaris-backup: \_validate_local_environment(), \_prepare_local_directories(), active collector path constants

## Implementation boundary

This should be implemented before the larger dispatcher refactor so the existing workflow becomes complete and safe first.

## Finding 3.4.1 - Normalize Collector Namespaces and Module Constants

What needs to change

Give every collector a complete collector-specific namespace for constants, mutable state, helper functions, and result codes. Replace generic names such as MODULE_NAME, COLLECTOR_RESULT_SUCCESS, CONFIG_STATUS_NEW, COLLECTOR_DIR, FRAMEWORK_ROOT, \_validate_environment(), and \_write_manifest() where they can collide when multiple collector files are sourced into one orchestrator shell.

Purpose of the change

Prevent one sourced collector from overwriting another collector’s state or function definitions, and make ownership obvious during maintenance.

Why it needs to change

The reviewed collectors are not uniformly namespaced. pfSense and Proxmox retain generic constants, and most collectors use generic private function names. The current orchestrator works because collectors are sourced and invoked in controlled wrappers, but namespace collisions remain a reliability risk as new collectors are added or wrapper behavior changes.

Affected area

collectors/pfsense/pfsense.sh; collectors/proxmox/proxmox.sh; all collector helper-function names; orchestrator source boundaries

Implementation boundary

Do this before broader consolidation. Rename in one collector family at a time, validate syntax, source behavior, standalone collection, and the full orchestrator after each meaningful namespace change.

## Finding 3.4.4 - Standardize Staging, Failure Preservation, and Cleanup

What needs to change

Adopt a single lifecycle for staging initialization, partial-artifact preservation, successful handoff to the orchestrator, and failed-run cleanup. Every collector should explicitly define what remains after success, no-change, and failure.

Purpose of the change

Prevent stale workspaces, accidental deletion of troubleshooting evidence, and inconsistent recovery behavior.

Why it needs to change

Admin01, Admin-WS, Docker01, pfSense, and OPNsense implement collector-level failure preservation and cleanup. Manual-export collectors rely more heavily on the orchestrator, and Proxmox uses its older collection structure. The framework currently succeeds, but the evidence-preservation and cleanup responsibilities are not uniform across collectors.

Affected area

All collectors; common failure-preservation helpers; orchestrator lifecycle and quarantine handling

Implementation boundary

Treat this as a high-risk change. First approve the division of responsibility between collector and orchestrator. Implement and regression-test one collector family at a time.

# Finding 3.4.9 - Bring Proxmox Into the Common Collector Contract Incrementally

## What needs to change

Refine the Proxmox collector in controlled steps so its namespaces, metadata, manifest, staging, result contract, failure handling, and public interface match the rest of the framework. Preserve its detailed collection scope and modular subsystem functions.

## Purpose of the change

Remove the largest consistency exception without risking a full rewrite of the most comprehensive collector.

## Why it needs to change

Proxmox predates the newer collector pattern and is substantially larger than every other collector. It uses generic module constants, an older manifest format, and different lifecycle conventions. It is operational and valuable, so replacing it wholesale would create unnecessary risk; leaving it permanently outside the common contract increases long-term maintenance cost.

## Affected area

collectors/proxmox/proxmox.sh; shared metadata/manifest helpers; orchestrator Proxmox wrapper

## Implementation boundary

No big-bang rewrite. Apply namespace and contract changes first, then metadata/manifest changes, then lifecycle alignment, with a full Proxmox archive comparison after each stage.

## Finding 3.4.2 - Define One Collector Interface and Result-Code Contract

What needs to change

Standardize the public collector entry point, required parameters, success/error/no-change result codes, and the meaning of each return value. Every active collector should expose one clearly named collect\_\<collector\>() function and use the same numeric contract.

Purpose of the change

Let the orchestrator treat collectors predictably and reduce collector-specific branching.

Why it needs to change

The configuration collectors generally use success=0, error=1, and no-change=2, but naming varies and Proxmox follows a different historical pattern. Full-inventory collectors always produce a new collection while hash-based and manual-export collectors can return no-change. The distinction is valid, but the interface and documented semantics should be uniform.

Affected area

All active collectors; bin/polaris-backup collector wrappers and lifecycle processing

Implementation boundary

Preserve current behavior. The refinement is a contract normalization, not a change to whether a collector is change-detected or always collected.

# Finding 3.4.11 - Apply One Sensitive-Artifact Collection Policy

## What needs to change

Create and enforce one collector policy defining which identity, key, credential-adjacent, certificate, serial-number, and user-environment artifacts are allowed. Explicitly exclude private keys, password stores, tokens, browser secrets, and unrestricted user content, and normalize file permissions on all generated artifacts.

## Purpose of the change

Ensure future refactoring or collector additions cannot accidentally expand backup scope into sensitive secrets or large user datasets.

## Why it needs to change

The current Admin01 and Admin-WS collectors intentionally collect public keys, authorized-key material, tool configuration, and workspace metadata while excluding private keys and credentials. Proxmox collects certificate and system identity information. The current choices appear deliberate, but the policy is encoded independently in collector logic rather than enforced as a framework-wide rule.

## Affected area

Admin01; Admin-WS; Proxmox; remote-output helper; metadata summaries; future collector checklist

## Implementation boundary

Review each currently collected artifact before changing scope. The goal is a documented allow/exclude policy and consistent permissions, not automatic removal of useful recovery material.

# Finding 3.4.12 - Create a Standard Collector Acceptance Test Matrix

## What needs to change

Define one repeatable validation matrix that every current and future collector must pass: syntax, source isolation, environment validation, success path, no-change path where applicable, controlled failure, troubleshooting preservation, manifest verification, archive verification, NAS verification, and orchestrator regression.

## Purpose of the change

Turn the successful incremental validation methodology used during development into a reusable release gate.

## Why it needs to change

Each collector was validated carefully, but the exact test commands and expected artifacts evolved during implementation. A common matrix will make Phase 3.5 safer and prevent future collectors from being considered complete with a weaker validation standard.

## Affected area

All collectors; Phase 3.5 implementation plan; post-refinement v1.0 audit and SOPs

## Implementation boundary

Keep tests operational and command-based. Do not expand this into a separate testing platform.

# Finding 3.4.10 - Normalize Optional-Artifact and Unavailable-Data Handling

## What needs to change

Define one policy for optional configuration that is absent, unavailable, unsupported, or intentionally excluded. Use consistent placeholder content, status labels, artifact naming, and summary reporting.

## Purpose of the change

Distinguish a successful collection with no applicable data from an incomplete or failed collection.

## Why it needs to change

Docker01 creates explicit placeholders for optional files, Proxmox writes several forms of “not present” or “unavailable,” and other collectors either omit artifacts or use collector-specific sentinel text. These approaches are understandable individually but complicate cross-collector audits and recovery reviews.

## Affected area

Docker01 optional configuration; Proxmox capability/configuration artifacts; Admin01/Admin-WS optional user tooling; future collectors

## Implementation boundary

Do not force empty artifacts where omission is clearer. Approve a small set of statuses and apply them consistently.

# Finding 3.4.5 - Normalize Metadata and Manifest Output

## What needs to change

Define one required metadata set and one manifest schema for every collector. At minimum, normalize collector-info, execution, collection-summary, manifest header, relative-path rules, size units, SHA-256 field naming, artifact count, status vocabulary, and framework-version reporting.

## Purpose of the change

Make archives self-describing and make validation tooling independent of collector type.

## Why it needs to change

Admin01, Admin-WS, and Docker01 already produce closely aligned metadata. pfSense and OPNsense omit some fields used by newer collectors. Manual-export collectors combine metadata differently. Proxmox uses a different manifest header and older metadata layout. The information is generally present, but the schema is not fully consistent.

## Affected area

All collectors; lib/polaris-common.sh manifest/metadata helpers; post-Phase 3 inventory documentation

## Implementation boundary

Approve the final schema before edits. Preserve backward readability of existing archives; normalization applies to newly generated backups.

# Finding 3.4.6 - Consolidate the Three Manual-Export Collectors

## What needs to change

Replace the largely parallel Switch01, Nano AP, and Nano Station implementations with one shared manual-export collection service or one parameterized collector template. Device-specific values should remain explicit parameters: module name, display name, artifact prefix, intake filename, and destination naming.

## Purpose of the change

Eliminate three copies of the same presence check, staging, hash comparison, metadata, manifest, and result-code logic.

## Why it needs to change

The three scripts have the same six-function structure and the same operational workflow, with most differences limited to names and intake filenames. Maintaining separate full implementations creates unnecessary duplication and makes fixes easy to apply to one device but miss on the others.

## Affected area

collectors/switch01/switch01.sh; collectors/nano-ap/nano-ap.sh; collectors/nano-station/nano-station.sh; shared library or a dedicated manual-export helper

## Implementation boundary

Do not hide device identity. A thin device-specific wrapper around a shared implementation is preferable to a single opaque configuration file.

# Finding 3.4.7 - Consolidate the pfSense and OPNsense Collector Core

## What needs to change

Extract the duplicated firewall-configuration workflow into shared, parameterized mechanics while retaining separate pfSense and OPNsense wrappers for host, user, key, remote path, naming, and device-specific validation.

## Purpose of the change

Maintain one tested implementation for SSH acquisition, remote hashing, baseline lookup, comparison, finalization, metadata, manifest generation, failure preservation, and temporary-file cleanup.

## Why it needs to change

The two firewall collectors have the same function sequence and nearly identical line count. Their differences are mainly namespace and device parameters. Keeping two full copies increases the risk of behavioral drift, but merging them without explicit wrappers would make device-specific recovery harder to understand.

## Affected area

collectors/pfsense/pfsense.sh; collectors/opnsense/opnsense.sh; lib/polaris-common.sh or a dedicated firewall helper

## Implementation boundary

High-risk because both are production firewall backups. First namespace pfSense, then prove behavior parity, then extract one helper at a time with separate end-to-end validation for both devices.

# Finding 3.4.8 - Centralize Runtime Connection Settings Without Hiding Collector Identity

## What needs to change

Move environment-specific host addresses, remote users, SSH key paths, connection timeouts, intake paths, and remote configuration paths into one approved runtime-settings layer. Keep module identity, collection scope, and device defaults visible in each collector.

## Purpose of the change

Make address, key, or path changes possible without editing production collection logic and reduce accidental configuration drift.

## Why it needs to change

Connection and intake settings are currently hardcoded throughout collector scripts. Admin-WS also references a key named for Admin01, which works but obscures intent. The current environment is stable, yet scheduled operation and future system additions will be easier to maintain with one controlled settings source.

## Affected area

Admin01, Admin-WS, Docker01, pfSense, OPNsense, Switch01, Nano AP, Nano Station; orchestrator startup validation

## Implementation boundary

Avoid building a configuration platform. A small root-owned shell settings file with explicit readonly values is sufficient if approved.

## Finding 3.4.3 - Normalize Collector Bootstrap and Environment Validation

What needs to change

Use one collector bootstrap pattern for load guards, collector-directory discovery, framework-root discovery, common-library sourcing, root checks, required-command checks, and required path/key validation.

Purpose of the change

Make every collector fail early in the same way and reduce repeated setup logic.

Why it needs to change

Admin01, Admin-WS, Docker01, pfSense, OPNsense, and Proxmox use one style, while Switch01 and the Nano collectors use a more heavily namespaced initialization sequence. Required-command and remote-access validation also differ by collector. These differences increase review effort and make future collector creation less predictable.

Affected area

All active collector scripts; lib/polaris-common.sh after Phase 3.2 decisions

Implementation boundary

Keep device-specific prerequisites inside each collector. Consolidate only the mechanics of checking them and reporting failures.

## 3.2.1 Remove or intentionally adopt unused common-library interfaces

What needs to change

Review and remove, or deliberately begin using, common functions and constants that have no active production call sites. The current candidates are directory_exists(), file_exists(), path_is_writable(), generate_timestamp(), safe_copy(), safe_copy_directory(), safe_copy_file(), safe_move(), collect_optional_directory(), POLARIS_CONFIG_DIR, POLARIS_TEMP_DIR, POLARIS_DOCS_DIR, and the default framework-log path.

Purpose

Reduce the public API to functionality the production framework actually depends on, making the shared library easier to understand and safer to extend.

Why it needs to change

The functions and constants are presented as supported shared services but are not used by the active orchestrator or current collectors. Retaining unused API creates maintenance obligations, obscures the true dependency surface, and can mislead future collector development.

Implementation boundary

Decide item-by-item during the implementation review. Remove dead interfaces unless another approved Phase 3 change will immediately adopt them.

## 3.2.2 Normalize ownership and naming of shared framework paths

What needs to change

Reconcile the shared path constants with the intended directory ownership. In particular, distinguish project-wide paths from configuration-backup paths and establish one authoritative location for framework logs and temporary data.

Purpose

Prevent path ambiguity and ensure scheduled execution writes operational data to predictable locations.

Why it needs to change

polaris-common.sh derives project-level paths such as POLARIS_LOG_DIR and POLARIS_TEMP_DIR, while the reviewed snapshot also contains logs and temp data inside config-backup. The orchestrator then appends config-backup/orchestrator beneath the project log root. The behavior can work, but the current naming and repository layout do not communicate one clear model.

Implementation boundary

Choose either project-wide operational roots or component-local operational roots, then update names, comments, directory preparation, and cleanup rules together. Validate all log and temporary paths after the change.

## 3.2.3 Define one explicit reporting and logging contract

What needs to change

Refine report\_\*, operator\_\*, and log\_\* so each family has one unambiguous responsibility and consistent severity behavior while preserving the approved minimal console-output policy.

Purpose

Reduce repeated message calls and ensure important warnings and failures are captured in the correct destination without relying on every caller to duplicate them manually.

Why it needs to change

report_info() and report_success() currently write through the logging service, while report_warning() and report_error() write to the console. operator\_\* also writes to the console, and many orchestrator paths pair report_error() with log_error(). The names therefore do not consistently indicate destination or behavior, which increases duplication and the risk that a new caller logs or displays the wrong message.

Implementation boundary

Approve the final semantic model before editing. A safe model is: operator\_\* for console only, log\_\* for log only, and either remove report\_\* or make report\_\* explicitly perform a documented combined action. Do not increase normal console verbosity.

## 3.2.4 Centralize manifest generation with controlled modes

What needs to change

Move the common manifest mechanics into polaris-common.sh. The helper should support at least two controlled modes: recursively include all permanent artifacts except the manifest, or process an explicit required-file list.

Purpose

Provide one implementation for file validation, relative-path handling, size collection, SHA-256 generation, deterministic ordering, artifact counting, and manifest permissions.

Why it needs to change

Admin01, Admin-WS, Docker01, Proxmox, pfSense, OPNsense, Switch01, NANO-AP, and NANO-STATION each implement substantially similar manifest logic. Differences in error handling and manifest headers have already developed. Manifest correctness is foundational to archive validation, so duplicated implementations create unnecessary regression risk.

Implementation boundary

Preserve current manifest formats unless a separate metadata-normalization decision approves a format change. Migrate one low-complexity collector first, validate its manifest byte-for-byte or semantically, then proceed collector group by collector group. Proxmox should migrate last because it has a richer header.

## 3.2.5 Add a shared SSH execution primitive

What needs to change

Create a small shared SSH helper that accepts host, user, key, timeout, and remote command, and consistently applies unattended-operation options such as BatchMode and IdentitiesOnly. Collector-specific wrappers should remain as thin adapters.

Purpose

Standardize transport behavior without merging collector-specific collection logic.

Why it needs to change

Admin01, Admin-WS, Docker01, pfSense, and OPNsense all execute remote commands with similar SSH setup, but option sets and error handling are implemented separately. A shared primitive would reduce repeated transport code and make future security or timeout changes easier to apply consistently.

Implementation boundary

Keep host-specific names, commands, and messages in each collector. Introduce the helper, migrate one collector, test interactive-prompt prevention and failure handling, then migrate the remaining SSH collectors in small groups.

# Finding 3.3.4 - Create One Authoritative Collector Registry

## What needs to change

Represent each active collector in one orchestrator-owned registry containing its machine name, display name, script path, interface function, working path, troubleshooting path, backup-name prefix, and any special invocation mode.

## Purpose of the change

Eliminate the need to register a collector separately in constants, main(), prerequisite validation, directory preparation, wrapper functions, lifecycle calls, and retention paths.

## Why it needs to change

Collector registration is currently distributed across many sections of a 3,900-line script. The incomplete preparation of newer collectors demonstrates the maintenance risk: adding a collector can succeed in one part of the orchestrator while being omitted from another. A single registry would make additions such as CA01 less error-prone and would provide a clear inventory of enabled collectors.

## Affected area

bin/polaris-backup: component constants, main(), environment validation, directory preparation, collector wrappers, lifecycle and retention calls

## Implementation boundary

The registry should remain simple Bash data, not become a plugin platform or external catalog. Collector-specific exceptions such as manual-export collectors may retain small adapter functions.

# Finding 3.3.5 - Consolidate Repeated Main-Workflow Result Handling

## What needs to change

Replace the nine nearly identical collector result case blocks in main() with a common handler that receives collector metadata and the wrapper result, invokes lifecycle processing when appropriate, quarantines failed output when present, and records the overall result.

## Purpose of the change

Reduce duplicated control flow while preserving the approved behavior that one collector failure does not prevent later collectors from running.

## Why it needs to change

The main function repeats backup-name construction, lifecycle calls, no-change messages, failed-output quarantine checks, unexpected-status handling, and overall-result updates for each collector. This increases review effort and makes small differences or omissions likely. A common handler would make behavior uniform and shorten the primary workflow enough to audit reliably.

## Affected area

bin/polaris-backup: main()

## Implementation boundary

This is a meaningful refactor and should be implemented only after the P1 corrections, one structural change at a time, with a full all-collector regression run.

# Finding 3.3.6 - Consolidate Standard Collector Wrapper Logic

## What needs to change

Create a standard collector runner for the repeated load, interface validation, timing, logging, exit-code translation, and operator-message sequence. Keep narrow adapter wrappers only for collectors with materially different arguments or no-change semantics.

## Purpose of the change

Reduce approximately repeated wrapper code while keeping collector-specific collection logic inside each collector.

## Why it needs to change

The Docker01, Admin01, and Admin-WS wrappers are nearly identical, and the remaining wrappers repeat most of the same structure. Every wrapper sources a script, verifies an interface, starts timing, emits the same log boundary, calls one function, translates 0/1/2, and emits the same completion records. Maintaining separate copies makes future logging or status changes require many synchronized edits.

## Affected area

bin/polaris-backup: \_run\_\*\_collector() functions

## Implementation boundary

Do not force pfSense, OPNsense, or manual-export collectors into an abstraction that obscures their baseline or no-export behavior. The approved design should support explicit adapters.

# Finding 3.3.7 - Isolate Collector Imports and Validate Namespace Boundaries

## What needs to change

Run sourced collectors in a controlled subshell or otherwise enforce an explicit namespace boundary so collector-private variables and functions cannot overwrite orchestrator or previously loaded collector state.

## Purpose of the change

Prevent cross-collector side effects and make collector execution deterministic as more collectors are added.

## Why it needs to change

Each collector is sourced into the orchestrator process. Even with current naming conventions and load guards, sourced Bash files can modify shell options, globals, traps, and function definitions. Project Polaris has already encountered namespace-related collector defects during development. Isolation would reduce the chance that a future collector changes the behavior of later collectors or the lifecycle engine.

## Affected area

bin/polaris-backup: all \_run\_\*\_collector() functions and collector import behavior

## Implementation boundary

This change requires careful validation because collectors currently depend on the shared common library and return status through the orchestrator shell. It should not be combined with the generic wrapper refactor unless the implementation review explicitly approves that risk.

# Finding 3.3.8 - Add Deterministic Interrupted-Run Recovery for Current and NAS Incomplete Paths

## What needs to change

Define a consistent startup policy for non-empty /staging/current/\<collector\> paths and abandoned NAS incomplete directories. Preserve them into timestamped quarantine or troubleshooting storage with a recorded reason, then allow a new scheduled run to proceed when preservation succeeds.

## Purpose of the change

Allow safe unattended recovery after host shutdown, process termination, network loss, or NAS interruption without silently deleting evidence or requiring manual cleanup before every subsequent run.

## Why it needs to change

The current preparation logic stops when certain working directories contain prior data, while later collectors are not checked consistently. NAS temporary directories are rejected when they already exist but are not reviewed at startup, and incomplete copies have no independent cleanup path. The existing preservation-first philosophy is correct, but it needs one deterministic policy across all collectors and both local and NAS temporary storage.

## Affected area

bin/polaris-backup: \_prepare_local_directories(), \_copy_to_nas_temporary(), \_quarantine_local_backup(), \_quarantine_nas_copy()

## Implementation boundary

No stale data should be deleted automatically until it has been preserved or positively identified as an empty framework-created directory.

# Finding 3.3.9 - Normalize Overall Exit-Status Precedence and Final Run Summary

## What needs to change

Define an explicit severity order for prerequisite, internal, collector, NAS, and lock failures, and produce one end-of-run summary showing each collector result, lifecycle result, NAS disposition, and the final selected exit code.

## Purpose of the change

Make scheduled execution and alerting accurately communicate the most significant failure while retaining a readable record of partial success.

## Why it needs to change

The current overall_result keeps the first non-success result encountered. A later internal error can therefore be masked by an earlier lower-severity failure, while the console ends with only a general success or failure statement. Logs contain detailed events, but automation and operators would benefit from a deterministic final status table or compact summary.

## Affected area

bin/polaris-backup: main(), collector result handling, final operator output

## Implementation boundary

The summary should remain concise and must not duplicate all detailed log messages on the console.

## Finding 3.1.5

What needs to change

Review log retention.

Current framework includes:

logs/framework.log

Purpose

Prevent unlimited log growth.

Why

Once cron/systemd is enabled, logs become long-lived operational artifacts.

Log rotation should be reviewed before automation begins.

Priority:

P2

## Finding 3.1.6

What needs to change

Review repository cleanliness before v1.0.

Examples include:

swap files

temporary validation artifacts

historical backup scripts

Purpose

Prepare for long-term maintenance.

Why

The repository should represent production code only.

Priority:

P2

## Finding 3.1.1

What needs to change

Remove historical production script copies from the active framework tree.

Examples identified:

bin/polaris-backup.pre-fd-fix

bin/polaris-backup.pre-multicollector

collectors/opnsense/opnsense.sh.pre-namespace-fix

collectors/pfsense/pfsense.sh.pre-rebuild-20260728

collectors/pfsense/pfsense.sh.truncated-20260728

collectors/proxmox/.proxmox.sh.swp

Purpose

Reduce maintenance confusion.

Ensure there is exactly one production implementation for every component.

Why

These files were valuable during development, but now increase the chance of editing or executing the wrong version.

Priority:

P2

Effort:

Small

Risk:

Very Low

# Finding 3.3.10 - Refresh Orchestrator Release Metadata and Make Operational Settings Explicit

## What needs to change

Update the script header, current scope, workflow description, and version after approved refinements. Review whether site-specific paths and retention periods should remain constants in the script or move to one small root-owned configuration file before scheduled execution.

## Purpose of the change

Ensure the v1.0 orchestrator accurately describes all nine active collectors and gives operators one clear location for intentional environment settings.

## Why it needs to change

The header still states a current scope limited to Proxmox and pfSense and version 0.2.0, despite the production orchestrator supporting nine collectors. Paths and retention values are valid for the current homelab but are embedded among program constants. At minimum the release metadata must be corrected; a minimal configuration file may reduce future code edits, provided it does not add unnecessary platform complexity.

## Affected area

bin/polaris-backup: file header, version constants, path and retention constants

## Implementation boundary

The configuration-file portion is optional and should be rejected if it adds more maintenance burden than value. Metadata correction is required for the final v1.0 release.

## 3.2.6 Centralize remote-command output validation

What needs to change

Extract the repeated execute-to-file sequence used by Admin01 and Admin-WS into a shared or transport-adjacent helper: execute, capture stdout/stderr, secure the artifact, and reject empty output when emptiness is not allowed.

Purpose

Remove near-identical artifact-handling code and make remote output requirements consistent.

Why it needs to change

The Linux and Windows administrative collectors contain almost identical \_remote_execute_to_file() implementations. Any future change to permissions, empty-output policy, or error reporting currently requires synchronized edits.

Implementation boundary

The helper must allow collectors to opt into empty-output placeholders where a command can legitimately return nothing. Do not force every remote command into one behavior.

## 3.2.7 Consolidate failure-artifact preservation only where behavior is equivalent

What needs to change

Evaluate a parameterized shared helper for the repeated troubleshooting-directory creation, staging preservation, failure-summary generation, and permissions used by Admin01, Admin-WS, Docker01, pfSense, and OPNsense.

Purpose

Reduce repeated failure-path code while retaining collector-specific diagnostic context.

Why it needs to change

Several collectors implement the same preservation lifecycle with different variable names and minor metadata differences. Failure paths are rarely exercised during normal operation, so duplicated versions are more likely to drift unnoticed.

Implementation boundary

Consolidate only the common mechanics. Keep collector-specific summary fields and temporary-file cleanup in the collector. This should be approved only if the helper remains simpler than the combined duplicated code and can be validated with intentional failure tests.

## 3.2.8 Normalize the common-library header, API list, and formatting

What needs to change

Correct the public API block, spacing, section labels, and function formatting in polaris-common.sh, then ensure the header lists only interfaces retained after the Phase 3.5 decisions.

Purpose

Make the shared library self-documenting and prevent stale API guidance.

Why it needs to change

The reviewed header contains merged comment text, uneven section formatting, an incomplete relationship between listed and implemented functions, and formatting anomalies around report_info(). These do not currently prevent execution but reduce readability and confidence during maintenance.

Implementation boundary

Perform this after functional consolidation decisions so the header documents the final v1.0 API rather than the transitional one.

## 3.2.9 Define the framework-version and collector-version policy

What needs to change

Document whether POLARIS_FRAMEWORK_VERSION tracks the shared API, the complete backup product, or the orchestrator release, and define when individual collector versions must change.

Purpose

Make version metadata useful for support, archive interpretation, and future collector upgrades.

Why it needs to change

The common library and orchestrator currently use development-era version values while collectors maintain independent versions. Without a stated policy, version changes can become cosmetic and archives cannot reliably communicate compatibility.

Implementation boundary

Choose and document the policy before declaring v1.0. Apply version updates only after all approved Phase 3.5 changes and regression testing are complete.

# 3. Consolidation Boundaries - Do Not Change Without Separate Approval

### Collector-specific collection logic

Commands and source-specific recovery artifacts should remain in the collector that owns them.

### Human-readable subsystem summaries

These encode host-specific operational meaning and should not be replaced by an overly generic formatter.

### Minimal operator console policy

Shared logging changes must preserve the already approved concise console output.

### Independent collector failure isolation

A shared helper must not cause one collector failure to corrupt or halt unrelated collector evidence.

### Lifecycle ownership

Archive creation, NAS promotion, quarantine, and retention remain orchestrator responsibilities unless the Phase 3.3 review separately approves a change.

# 4. Recommended Phase 3.5 Order for Shared-Library Changes

# 5. Phase 3.2 Decision Statement

The shared library should be refined, not expanded into a generalized software platform. The approved direction should centralize only code that is genuinely repeated, operationally stable, and simpler as a shared service. High-impact consolidation must be implemented one change at a time with targeted validation and full regression testing. Lower-risk API cleanup and documentation normalization may be grouped after the shared behavior is stable.

## Finding 3.1.2

What needs to change

Clean development validation directories under temp/.

The framework currently contains numerous stage-by-stage validation trees retained from collector development.

Purpose

Reduce clutter.

Reduce storage usage.

Improve readability.

Why

These directories are no longer required for production operation.

The production framework should generate new validation directories when needed.

Priority:

P2

Effort:

Small

Risk:

Very Low

## Finding 3.1.3

What needs to change

Separate production framework assets from engineering artifacts.

Purpose

Clearly distinguish:

Production

vs.

Development

vs.

Historical

Why

The framework currently mixes all three.

Suggested future layout (concept only):

config-backup/

bin/

collectors/

lib/

engineering/

archived-builds/

historical-tests/

development-notes/

No implementation yet.

Priority:

P3

Effort:

Medium

Risk:

Low

## Finding 3.1.4

What needs to change

Normalize framework versioning.

Example observed:

polaris-common.sh

Framework Version

0.2.0

Collector versions currently evolve independently.

Purpose

Prepare for v1.0 release.

Why

Versioning should reflect a released framework instead of development iterations.

I recommend deciding during Phase 3.5 whether:

every collector keeps an independent version

or

framework version becomes authoritative

This is a design decision, not an implementation recommendation yet.

Priority:

P3

## Finding 3.1.7

What needs to change

Review roadmap/documentation references after Backup Framework v1.0.

The uploaded roadmap still references collector work that has since been completed, while other planning documents reflect earlier phases.

Purpose

Keep documentation synchronized with the production implementation.

Why

Once Phase 3 is complete, the documentation should describe the finalized framework rather than its development history.

Priority:

P3

## Finding 3.1.8

What needs to change

Review the maintenance backlog after Phase 3.

Several backlog entries refer to work that has been completed or whose sequencing has changed because of the revised roadmap.

Purpose

Keep the backlog actionable.

Why

A backlog is most useful when every remaining item still reflects future work.

Priority:

P3

# Phase 3.5 Implementation Notes

- Use this document only as an implementation checklist.

- Address P1 items before P2 and P3 unless dependencies require otherwise.

- Validate each high-risk change independently.

- Combine only low-risk changes after individual validation has been completed.

- Perform a final inventory audit after all approved refinements are complete.
