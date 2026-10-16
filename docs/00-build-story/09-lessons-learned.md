# Chapter 9 — Lessons Learned

1. **Audit the runtime, not the config page.** The firewall alias typo (`127.16/12` instead of `172.16/12`) and the Tailscale "isolation" that was really an allow-all policy both looked fine in the configuration. They only showed up when I read what was actually loaded and running.
2. **A test that passes has not necessarily tested the rule.** Confirm that the rule under test was the deciding factor, and read the execution trace, not just the output.
3. **Prompts reduce probability; architecture removes possibility.** If an action must never happen without a human, take away the AI's ability to trigger it.
4. **Back up first, change one thing, validate, then write it down.** Every gate in this project followed that order, and every recovery was quick because of it.
5. **Name accepted risks out loud.** A single DC, a single-disk NAS, LXC GPU sharing and double NAT are all fine as long as they are written down with a compensating control, not quietly normalized.
6. **Vendor documentation can be wrong.** "Applies immediately", a `success: true` field and a stable-looking `id` were each wrong at least once with the pfSense API. Verify each endpoint against an independent read.
7. **Rebuild instead of nursing a broken system.** The corrupted pfSense, the BlackArch VM and the Debian-based AI container were all fixed faster by rebuilding cleanly than by repairing them.
8. **Layer-2 isolation is not automatic.** Two "separate" networks shared one Linux bridge until the cutover audit found it.
9. **Telemetry gaps hide attacks.** Linux discovery commands went unseen until auditd execve rules were added. Validate detections with real emulation.
10. **Documentation is part of the system.** Without the ID scheme, the register and the decision logs, this lab could not be operated, recovered or explained.
