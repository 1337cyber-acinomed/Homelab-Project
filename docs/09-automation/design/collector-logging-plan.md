<!-- Converted from Word document: Logging.docx -->

We are missing logging. To maintain easy referencing for troubleshooting each collector with the orchestrator logging for the collector should be the last step done prior to the next collector so that I don't have the reports from proxmox collector while trying to do the pfsense collector. the next step should be -\> build logger for proxmox collector in orchestrator -\> pfsense collector -\> pfsense collector logger -\> opsense -\> opsense logger -\> etc. 1. I agree with the ordering just need to build the loggers at the end of each collector validation for that collector.

Agreed. The logger belongs at the end of each collector’s validation cycle, before moving to the next collector.

That sequencing keeps troubleshooting isolated and prevents Proxmox collector output from being mixed with pfSense development and test output.

**Revised Collector Roadmap**

| **Order** | **Component**                                       | **Status**             |
|-----------|-----------------------------------------------------|------------------------|
| 1         | Proxmox collector                                   | Complete and validated |
| 2         | Proxmox collector logging through the orchestrator  | **Next**               |
| 3         | pfSense collector                                   | Pending                |
| 4         | pfSense collector logging through the orchestrator  | Pending                |
| 5         | OPNsense collector                                  | Pending                |
| 6         | OPNsense collector logging through the orchestrator | Pending                |
| 7         | Docker collector                                    | Pending                |
| 8         | Docker collector logging through the orchestrator   | Pending                |
| 9         | Linux collector                                     | Pending                |
| 10        | Linux collector logging through the orchestrator    | Pending                |
| 11        | Windows collector                                   | Pending                |
| 12        | Windows collector logging through the orchestrator  | Pending                |
| 13        | NAS collector                                       | Pending                |
| 14        | NAS collector logging through the orchestrator      | Pending                |
| 15        | Full multi-collector orchestrator validation        | Pending                |
| 16        | Final workflow documentation and restore framework  | Pending                |

**Collector completion standard**

A collector will not be considered complete until all of these pass:

Build collector

↓

Run independently

↓

Validate generated manifest

↓

Run through orchestrator

↓

Validate local archive and NAS replication

↓

Implement collector-specific logging

↓

Validate logs during success and failure

↓

Freeze collector

**Next step**

The next development batch is:

**Proxmox Collector Logger**

The logger should provide a clean record for each orchestrated Proxmox run, including:

- run identity and timestamp

- collector name and version

- collector start and completion

- individual collection stages

- warnings and errors

- manifest validation result

- archive and NAS replication result

- final workflow result and exit code

- paths to the validated backup, archive, NAS copy, and verification reports

The next code change should begin by reviewing the existing logging functions in polaris-common.sh and identifying where the orchestrator currently initializes and writes its log file.

I agree with this, one additional thing that I will let you determine the best time to put in whether now or after collectors are built. If a collector experiences a fatal error, the orchestrator should stop it and continue with the next collector. It should not stop the collection process. 1. This is the only logging implementation we have done in the polaris-common.sh file and we have not started anything for reporting yet.

Yesterday 8:22 AM
