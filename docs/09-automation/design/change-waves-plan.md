<!-- Converted from Word document: change waves.docx -->

**Wave 0 – Documentation Only (No Code)**

**Purpose:** Finalize design decisions before touching production code.

Includes:

- 3.2.9 – Framework/collector version policy

- 3.1.4 – Framework versioning

- 3.1.7 – Documentation synchronization

- 3.1.8 – Maintenance backlog review

**Validation**

Documentation review only.

**Wave 1 – Collector Namespace Foundation (Standalone)**

This is the highest-risk collector change and should remain isolated.

Includes:

- 3.4.1 – Normalize collector namespaces and module constants

**Reason**

Everything else assumes namespace consistency.

Changing anything before this increases future merge risk.

**Wave 2 – Collector Contract (Standalone)**

Includes:

- 3.4.2 – Collector interface/result contract

**Reason**

This establishes the API the orchestrator will depend upon.

**Wave 3 – Common Library Transport Layer**

These all modify the same portion of polaris-common.sh.

Merge:

- 3.2.5 – Shared SSH primitive

- 3.2.6 – Remote output helper

- 3.4.8 – Runtime connection settings

**Reason**

Single subsystem.

Single regression.

No architecture overlap.

**Wave 4 – Common Library Artifact Layer**

Merge:

- 3.2.4 – Manifest helper

- 3.4.5 – Metadata normalization

- 3.4.10 – Optional artifact policy

- 3.4.11 – Sensitive artifact policy

These all affect artifact generation.

**Wave 5 – Failure Handling**

Merge:

- 3.2.7 – Failure artifact helper

- 3.4.4 – Collector lifecycle cleanup

Reason:

Same failure path.

**Wave 6 – Collector Bootstrap**

Merge:

- 3.4.3 – Bootstrap normalization

- 3.2.2 – Shared path ownership

Reason:

Startup logic.

**Wave 7 – Logging**

Merge:

- 3.2.3 – Reporting contract

- 3.1.5 – Log retention

Reason:

Entire logging subsystem.

**Wave 8 – Orchestrator Startup**

Merge:

- 3.3.2 – Independent retention

- 3.3.3 – Startup validation

- 3.3.8 – Interrupted-run recovery

Reason:

All startup behavior.

**Wave 9 – Orchestrator Refactor**

These should remain separated internally but can be reviewed together.

Sequence:

1.  3.3.4 – Collector registry

2.  validate

3.  3.3.6 – Wrapper consolidation

4.  validate

5.  3.3.5 – Main workflow consolidation

6.  validate

I would **not** merge these into one implementation because they touch too much shared control flow.

**Wave 10 – Orchestrator Completion**

Merge:

- 3.3.9 – Exit status

- 3.3.10 – Release metadata

- 3.3.1 – Archive growth

Reason:

End-of-run behavior.

**Wave 11 – Collector Consolidation**

Sequence:

1.  3.4.6 – Manual-export collectors

validate

2.  3.4.7 – pfSense/OPNsense

validate

3.  3.4.9 – Proxmox modernization

validate

These three are the largest collector changes and should **not** be merged with one another.

**Wave 12 – Library Cleanup**

Merge:

- 3.2.1 – Remove unused APIs

- 3.2.8 – Header/API cleanup

Reason:

Library-only cleanup after functional work is complete.

**Wave 13 – Repository Cleanup (Last)**

Merge:

- 3.1.6 – Repository cleanup

- 3.1.1 – Historical scripts

- 3.1.2 – Temp validation cleanup

- 3.1.3 – Engineering artifact separation

**Only after the entire framework has passed regression testing.**

**Wave 14 – Acceptance Testing**

- 3.4.12 – Standard collector acceptance test matrix

This becomes the release gate for v1.0.

**Items I intentionally did not merge**

I recommend keeping these isolated because combining them would make troubleshooting difficult:

- **3.4.1** (collector namespaces)

- **3.4.2** (collector contract)

- **3.3.4** (collector registry)

- **3.3.5** (main workflow refactor)

- **3.3.6** (wrapper consolidation)

- **3.4.6** (manual-export consolidation)

- **3.4.7** (pfSense/OPNsense consolidation)

- **3.4.9** (Proxmox modernization)
