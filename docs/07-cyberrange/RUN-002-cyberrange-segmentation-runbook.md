<!-- Converted from Word document: RUN-002_Project_Polaris_Cyberrange_Segmentation_Runbook_v1.23.docx -->

**Cyberrange Segmentation Runbook**

Recovery-first implementation of VLAN-aware vmbr1 and OPNsense security zones

| **Version**       | 1.23                                                                                                         |
|-------------------|--------------------------------------------------------------------------------------------------------------|
| **Status**        | Approved record - Gates 1-6, 7.1, 7.2A-7.2D, 7.3A, and 7.3C-1-7.3C-8 passed; 7.3B approved; Gate 7.3C closed |
| **Owner**         | Project Polaris                                                                                              |
| **Effective**     | 3 September 2026                                                                                             |
| **Design preset** | compact_reference_guide                                                                                      |

# Scope and authorization boundary

| **Authorized now:** No additional implementation action is authorized under RUN-002. Preserve the validated post-policy configuration export and evidence package. Gate 7.3C is complete and closed; any later guest attachment, behavioral testing, or policy change requires a separately released checkpoint. |
|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

| **Out of scope:** Do not restore, revert, edit, or select a historical configuration; do not edit or Apply a firewall rule; and do not change an alias, NAT, DNS/DHCP, IPv6, guest attachment, service, WAN/LAN policy, or upstream component. Behavioral guest testing remains outside this runbook. |
|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

# Approved design constants

| **Control**          | **Value**                                                                                                    |
|----------------------|--------------------------------------------------------------------------------------------------------------|
| Management           | Native VLAN 1 / 10.10.1.0/24; OPNsense 10.10.1.1; Kali01 10.10.1.85                                          |
| Attack               | VLAN 10 / 10.10.10.0/24                                                                                      |
| Vulnerable Windows   | VLAN 20 / 10.10.20.0/24                                                                                      |
| Vulnerable Linux     | VLAN 30 / 10.10.30.0/24                                                                                      |
| Vulnerable apps/APIs | VLAN 40 / 10.10.40.0/24                                                                                      |
| SIEM/monitoring      | VLAN 50 / 10.10.50.0/24                                                                                      |
| Scanners/analysis    | VLAN 60 / 10.10.60.0/24                                                                                      |
| Quarantine/malware   | VLAN 99 / 10.10.99.0/24; no upstream                                                                         |
| IPv6                 | Unused/disabled; must not create an alternate path                                                           |
| Runtime guardrail    | Approximately 24 GiB across running guests; inventory itself is not capped                                   |
| VMID allocation      | 300/301 retained for management; VLAN 10=310-319, 20=320-329, 30=330-339, 40=340-349, 50=350-359, 60=360-369 |
| Quarantine VMIDs     | VLAN 99 is temporary; retain the workload's existing VMID                                                    |

# Global safety controls

- Use the cyberrange local console or a management session on vmbr0 before changing vmbr1.

- Record commands and output with timestamps; preserve hashes for every exported/archive file.

- Never use a vulnerable guest to access NAS01 or the Proxmox management plane.

- Do not delete existing VM300 recovery points during this change.

- Do not force-stop Kali01 if graceful shutdown fails; investigate and stop the gate.

- Keep an unmodified local copy of /etc/network/interfaces and a NAS copy before ifreload.

- After each gate, compare observed state to the pass criteria and explicitly continue or stop.

# Gate 1 - Documentation freeze

The accepted Gate 1 baseline consists of ARC-001 v3.1, REG-001 v6.1, MB-001 v5.1, RM-001 v6.1, and RUN-002 v1.0. The v3.2/v6.2/v1.1 amendment adds the approved VLAN-aligned VMID convention and records Gate 2 completion without changing the Gate 1 result.

| **Gate 1 pass:** All five documents render cleanly and are accepted as the authoritative planning baseline. |
|-------------------------------------------------------------------------------------------------------------|

# Gate 2 - Kali01 pre-change recovery

Run on the cyberrange Proxmox shell. VM301 is currently expected to be running. A graceful shutdown, local ZFS snapshot, NAS vzdump, catalog validation, and restart are required.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>qm status 301<br />
qm config 301<br />
pvesm status | grep -E '^(Cyber_VM|NAS-Backups)'<br />
qm shutdown 301 --timeout 120<br />
qm status 301<br />
qm snapshot 301 pre-vlan-segmentation-20260821 --description "Pre-change checkpoint before cyberrange VLAN segmentation"<br />
qm listsnapshot 301<br />
vzdump 301 --storage NAS-Backups --mode stop --compress zstd<br />
pvesm list NAS-Backups --vmid 301<br />
qm start 301<br />
for attempt in $(seq 1 30); do<br />
[ "$(qm status 301 | awk '{print $2}')" = "running" ] &amp;&amp; break<br />
sleep 2<br />
done<br />
[ "$(qm status 301 | awk '{print $2}')" = "running" ]<br />
qm status 301</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

| **Stop condition:** Stop if VM301 does not shut down cleanly, the snapshot fails, NAS-Backups is inactive, vzdump returns nonzero, the backup catalog lacks VM301, or Kali01 does not restart. |
|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

| **Gate 2 pass:** VM301 has the named local snapshot, a current NAS-Backups archive, and returns to running state. |
|-------------------------------------------------------------------------------------------------------------------|

| **Recorded result:** PASSED 21 August 2026. Snapshot pre-vlan-segmentation-20260821 exists; archive vzdump-qemu-301-2026_08_21-14_38_34.vma.zst is present on NAS-Backups; VM301 returned to running. |
|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

# Gate 3 - OPNsense recovery confirmation

Confirm the current OPNsense XML export from Kali01 and the VM300 Proxmox recovery inventory. Do not delete older copies during this change.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th># On Kali01<br />
config_file="$(find "$HOME/Downloads" -maxdepth 1 -type f -name '*.xml' -printf '%T@ %p<br />
' | sort -nr | head -n 1 | cut -d' ' -f2-)"<br />
test -n "$config_file" &amp;&amp; stat "$config_file" &amp;&amp; sha256sum "$config_file"<br />
grep -c '&lt;opnsense' "$config_file"<br />
<br />
# On the cyberrange Proxmox shell<br />
qm status 300<br />
qm config 300<br />
qm listsnapshot 300<br />
pvesm list NAS-Backups --vmid 300<br />
pvesm list NAS-Infrastructure --vmid 300<br />
pvesh get /cluster/backup --output-format yaml | grep -E '(^| )(comment|enabled|id|node|schedule|storage|vmid|keep-last):|300'</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>Gate 3 pass:</strong> The XML exists, has one OPNsense root element, and has a recorded SHA-256 hash; at least one current recoverable VM300 backup is cataloged and VM300 configuration is captured.</p>
<p><strong>Recorded result:</strong> PASSED 21 August 2026. OPNsense XML size 72,167 bytes; SHA-256 7e65962735a3604d9f29bc4222f80911bb39a02a81ab809125879fa70e021d29; root-element count 1. VM300 was running; snapshots Post-Install-Clean and pre-update-26-7 were present; one NAS-Backups archive and two NAS-Infrastructure archives were cataloged. The enabled daily Tier one Backups job includes VM300 with keep-last 2.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

# Gate 4 - Cyberrange host configuration backup

Create a timestamped host archive locally, then copy it to NAS-Configurations. These commands are designed to capture network, storage, firewall, cluster, and VM300/301 configuration without changing them.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>stamp="$(date +%Y%m%d-%H%M%S)"<br />
workdir="/root/polaris-cyberrange-pre-vlan-$stamp"<br />
archive="/root/polaris-cyberrange-pre-vlan-$stamp.tar.gz"<br />
mkdir -p "$workdir"<br />
cp -a /etc/network/interfaces "$workdir/"<br />
cp -a /etc/network/interfaces.d "$workdir/" 2&gt;/dev/null || true<br />
cp -a /etc/pve/storage.cfg "$workdir/"<br />
cp -a /etc/pve/corosync.conf "$workdir/"<br />
cp -a /etc/pve/nodes/cyberrange/qemu-server/300.conf "$workdir/"<br />
cp -a /etc/pve/nodes/cyberrange/qemu-server/301.conf "$workdir/"<br />
pvesh get /cluster/backup --output-format yaml &gt; "$workdir/cluster-backup-jobs.yaml"<br />
ip -br address &gt; "$workdir/ip-br-address.txt"<br />
ip -4 route show &gt; "$workdir/ipv4-routes.txt"<br />
bridge vlan show &gt; "$workdir/bridge-vlan-show.txt"<br />
tar -C /root -czf "$archive" "$(basename "$workdir")"<br />
archive_root="$(basename "$workdir")"<br />
for required in interfaces storage.cfg corosync.conf 300.conf 301.conf cluster-backup-jobs.yaml ip-br-address.txt ipv4-routes.txt bridge-vlan-show.txt; do<br />
tar -tzf "$archive" "$archive_root/$required" &gt;/dev/null<br />
done<br />
tar -tzf "$archive" | sort<br />
(cd /root &amp;&amp; sha256sum "$(basename "$archive")") &gt; "$archive.sha256"<br />
nas_root="/mnt/pve/NAS-Configurations"<br />
test -d "$nas_root" &amp;&amp; test -w "$nas_root"<br />
nas_path="$nas_root/Project-Polaris/Cyberrange-Host"<br />
mkdir -p "$nas_path"<br />
cp -a "$archive" "$archive.sha256" "$nas_path/"<br />
ls -l "$archive" "$archive.sha256" "$nas_path/$(basename "$archive")" "$nas_path/$(basename "$archive").sha256"<br />
(cd "$nas_path" &amp;&amp; sha256sum -c "$(basename "$archive").sha256")</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

| **Stop condition:** If NAS-Configurations does not expose a writable path, do not guess or change storage configuration. Stop and resolve the destination before Gate 5. |
|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>Gate 4 pass:</strong> A local and NAS copy of the archive exist, the stored hash validates, and the archive contains the current bridge and VM300/301 configuration.</p>
<p><strong>Recorded result:</strong> PASSED 21 August 2026. The pre-change archive polaris-cyberrange-pre-vlan-20260821-152601.tar.gz was created, copied to /mnt/pve/NAS-Configurations/Project-Polaris/Cyberrange-Host/, and verified against its SHA-256 sidecar. Required members were present, including interfaces, storage.cfg, corosync.conf, VM300/301 configurations, cluster backup jobs, address/route output, and bridge VLAN output.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

# Gate 5 - Enable VLAN-aware vmbr1

Gate 5 changes only the cyberrange host bridge. Native untagged management remains VLAN 1. Perform from the cyberrange host console or vmbr0 management path; do not use Kali01 as the only control session.

<table>
<colgroup>
<col style="width: 46%" />
<col style="width: 53%" />
</colgroup>
<thead>
<tr class="header">
<th><strong>Before</strong></th>
<th><strong>After</strong></th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td>auto vmbr1<br />
iface vmbr1 inet manual<br />
bridge-ports none<br />
bridge-stp off<br />
bridge-fd 0</td>
<td>auto vmbr1<br />
iface vmbr1 inet manual<br />
bridge-ports none<br />
bridge-stp off<br />
bridge-fd 0<br />
bridge-vlan-aware yes<br />
bridge-vids 2-4094</td>
</tr>
</tbody>
</table>

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>cp -a /etc/network/interfaces /etc/network/interfaces.pre-vlan-20260821<br />
python3 - &lt;&lt;'PY'<br />
from pathlib import Path<br />
<br />
path = Path('/etc/network/interfaces')<br />
text = path.read_text()<br />
old = '''auto vmbr1<br />
iface vmbr1 inet manual<br />
bridge-ports none<br />
bridge-stp off<br />
bridge-fd 0'''<br />
new = old + '''<br />
bridge-vlan-aware yes<br />
bridge-vids 2-4094'''<br />
if text.count(old) != 1:<br />
raise SystemExit('Expected exactly one unchanged vmbr1 stanza; no edit made.')<br />
path.write_text(text.replace(old, new, 1))<br />
PY<br />
ifquery --check vmbr1<br />
ifreload -a<br />
ip -br address show vmbr0 vmbr1<br />
bridge vlan show<br />
qm status 300<br />
qm status 301<br />
ping -c 2 -W 2 192.168.10.120</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

| **Rollback:** If management or VM traffic is lost, restore /etc/network/interfaces.pre-vlan-20260821 to /etc/network/interfaces from the local console and run ifreload -a. If ifreload is unsafe or unavailable, stop and use the console-supported network reload/reboot plan only after review. |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>Gate 5 pass:</strong> vmbr0 management remains reachable; vmbr1 is VLAN-aware with VLANs 2-4094 available; VM300 and VM301 remain running; OPNsense WAN and native management remain reachable.</p>
<p><strong>Recorded result:</strong> PASSED 21 August 2026. vmbr1 reloaded successfully with ReloadExitCode 0 and vlan_filtering 1. vmbr0 remained UP at 192.168.10.119/24, vmbr1 retained no host IPv4 address, the default route remained through 192.168.10.1 on vmbr0, peer 192.168.10.2 remained reachable, and the two-node cluster plus QDevice remained quorate. Existing guest ports correctly remained VLAN 1 PVID/egress-untagged pending later guest tagging. The bridge-fd 0 parser warnings were pre-existing and non-blocking.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

# Gate 6 - Create OPNsense VLAN interfaces and gateway addresses

This gate creates only the approved VLAN objects, interface assignments, and static IPv4 gateway addresses on VM300 (cyber-fw01). It does not configure DHCP, DNS, NAT, or firewall policy; those controls remain Gate 7.

| **Change boundary:** Preserve VM300 WAN on vtnet0, untagged management LAN on vtnet1 at 10.10.1.1/24, Kali01 management at 10.10.1.85/24, and Admin01 emergency HTTPS access to 192.168.10.120. IPv6 remains disabled/unused. |
|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

## 6.1 Preconditions and approved mapping

- Gate 5 is passed and vmbr1 reports vlan_filtering 1.

- The Gate 4 cyberrange-host archive and its NAS copy are verified.

- The current OPNsense XML export and VM300 snapshot/NAS backup evidence remain available.

- No vulnerable workload is running or attached while interface objects are created.

| **VLAN** | **Interface description** | **Static IPv4 gateway** | **VMID family**        |
|----------|---------------------------|-------------------------|------------------------|
| 10       | CYBER_ATTACK              | 10.10.10.1/24           | 310-319                |
| 20       | CYBER_WINDOWS             | 10.10.20.1/24           | 320-329                |
| 30       | CYBER_LINUX               | 10.10.30.1/24           | 330-339                |
| 40       | CYBER_APPS                | 10.10.40.1/24           | 340-349                |
| 50       | CYBER_SIEM                | 10.10.50.1/24           | 350-359                |
| 60       | CYBER_ANALYSIS            | 10.10.60.1/24           | 360-369                |
| 99       | CYBER_QUARANTINE          | 10.10.99.1/24           | Existing VMID retained |

## 6.2 Controlled GUI procedure on OPNsense

1.  Sign in through Kali01 at https://10.10.1.1. Keep the Proxmox console open as the recovery path.

2.  Open Interfaces \> Devices \> VLAN (or Other Types \> VLAN on older layouts). Create VLANs 10, 20, 30, 40, 50, 60, and 99 with parent vtnet1 and descriptions matching the approved mapping.

3.  Open Interfaces \> Assignments. Add one interface for each new VLAN object.

4.  Open each assigned interface, enable it, set its description, choose Static IPv4, and assign the approved /24 gateway address. Set IPv6 Configuration Type to None.

5.  For these internal interfaces, leave Block private networks and Block bogon networks unchecked; later Gate 7 rules provide the isolation policy.

6.  Apply the interface changes. Record the OPNsense assignment name and device name for every VLAN.

7.  Stop. Do not enable DHCP, edit DNS services, change outbound NAT, or add/remove firewall rules in this gate.

## 6.3 Read-only validation

Run from the OPNsense console after the GUI changes are applied:

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>date "+%Y-%m-%dT%H:%M:%S%z"<br />
hostname<br />
sha256 -q /conf/config.xml<br />
awk '/&lt;vlans&gt;/{show=1} show{print} /&lt;\/vlans&gt;/{show=0}' /conf/config.xml<br />
awk '/&lt;interfaces&gt;/{show=1} show{print} /&lt;\/interfaces&gt;/{show=0}' /conf/config.xml<br />
ifconfig -a<br />
netstat -rn -f inet</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

Run from Kali01:

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>ping -c 2 -W 2 10.10.1.1<br />
curl -k -I --connect-timeout 5 https://10.10.1.1</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

Run from Admin01:

| curl -k -I --connect-timeout 5 https://192.168.10.120 |
|-------------------------------------------------------|

Run from the cyberrange Proxmox console:

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>ping -c 2 -W 2 192.168.10.2<br />
pvecm status</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

## 6.4 Stop conditions, rollback, and pass criteria

| **Stop immediately:** Stop if Kali01 loses 10.10.1.1, Admin01 loses 192.168.10.120, the host loses peer/cluster connectivity, a VLAN is assigned to vtnet0, or any unplanned DHCP, DNS, NAT, or firewall-policy change appears. |
|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

| **Rollback:** Use the Proxmox console. Restore the saved OPNsense XML through System \> Configuration \> Backups or the console recent-configuration restore path, perform the controlled reload/reboot requested by OPNsense, and repeat the management and cluster validation. Prefer full configuration restore over ad hoc removal of partially created interfaces. |
|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

| **Pass condition**        | **Required evidence**                                                        |
|---------------------------|------------------------------------------------------------------------------|
| Seven VLAN definitions    | Tags 10, 20, 30, 40, 50, 60, and 99; all use parent vtnet1                   |
| Seven enabled assignments | Descriptions and /24 gateway addresses match the approved mapping; IPv6 None |
| Management continuity     | Kali01 reaches 10.10.1.1; Admin01 reaches 192.168.10.120                     |
| Host/cluster continuity   | 192.168.10.2 responds and the Polaris cluster remains quorate                |
| Scope containment         | No DHCP, DNS, NAT, or firewall-policy change was made                        |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>Gate 6 release rule:</strong> Do not proceed to Gate 7 until all five pass conditions are evidenced and the post-change OPNsense configuration XML is exported and hashed.</p>
<p><strong>Recorded result:</strong> PASSED 28 August 2026. VLAN tags 10, 20, 30, 40, 50, 60, and 99 were created on parent vtnet1 and assigned as opt1-opt7 with the approved descriptions and addresses 10.10.10.1/24 through 10.10.60.1/24 plus 10.10.99.1/24. IPv6 remained disabled. The connected routes were present; Kali01 management at 10.10.1.1 and Admin01 emergency management at 192.168.10.120 both returned HTTP 200; peer 192.168.10.2 remained reachable; and the Polaris cluster reported Quorate: Yes. The live and exported 75,142-byte OPNsense XML files matched SHA-256 76f3077e1878a28dc5eb6df224dd09d5f7f856279e6110d917758d858c50868a, and the export contained one OPNsense root element. Kali01 ICMP to 10.10.1.1 remained blocked while HTTPS management remained available; no firewall-rule change was made to alter that existing behavior. No deliberate DHCP, DNS, NAT, or firewall-policy edit was made during Gate 6.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

# Gate 7 - Pre-policy recovery and service baseline

Gate 7 built the cyberrange's DHCP, DNS, protected alias use, outbound NAT posture, and default-deny firewall policy. Gates 7.1 through 7.3A completed and verified the isolated pre-policy foundation; Gate 7.3B approved the no-new-alias, per-interface, default-closed design; and Gates 7.3C-1 through 7.3C-8 completed active-purpose and quarantine policy staging, activation, integrity checks, management-continuity validation, and the final post-policy recovery export. The Gate 7.3C execution sequence is complete and closed.

| **Current boundary:** Gates 7.1, 7.2A-7.2D, 7.3A, and 7.3C-1-7.3C-8 are complete; Gate 7.3B is approved. All seven cyber interfaces retain their approved default-closed policies, both OPNsense management paths remained available, and the validated current-configuration XML is preserved as the post-policy recovery artifact. No further action is released by this runbook. |
|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

## 7.1A VM300 pre-policy recovery checkpoint

Run on the cyberrange Proxmox host. VM300 must remain running and the post-Gate 6 XML export must remain available on Kali01.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>set -euo pipefail<br />
<br />
VMID=300<br />
SNAPSHOT_NAME="post-vlan-interfaces-pre-policy-20260828"<br />
<br />
echo "=== GATE 7.1A: VM300 PRE-POLICY CHECKPOINT ==="<br />
date -Is<br />
qm status "$VMID"<br />
test "$(qm status "$VMID" | awk '{print $2}')" = "running"<br />
<br />
if qm listsnapshot "$VMID" | grep -Fq "$SNAPSHOT_NAME"; then<br />
echo "STOP: Snapshot already exists; do not overwrite or guess."<br />
exit 1<br />
fi<br />
<br />
qm snapshot "$VMID" "$SNAPSHOT_NAME" \<br />
--description "Validated Gate 6 VLAN interfaces before DHCP DNS NAT and firewall policy"<br />
<br />
qm listsnapshot "$VMID"<br />
qm status "$VMID"</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

| **Stop condition:** Stop if VM300 is not running, the snapshot already exists, snapshot creation fails, or VM300 does not remain running. |
|-------------------------------------------------------------------------------------------------------------------------------------------|

| **Recorded result:** PASSED 28 August 2026. Snapshot post-vlan-interfaces-pre-policy-20260828 was created at 20:57:38 local time with the validated Gate 6 description. Both virtual disks were snapshotted successfully and VM300 remained running. Guest filesystem freeze was unavailable in the VM options, so the existing matching post-Gate 6 XML export remains the application-level configuration recovery artifact. |
|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

## 7.1B GUI-first OPNsense service and policy baseline

Perform this gate through the OPNsense web interface from Kali01. The GUI is authoritative for normal operator work. A terminal command may be introduced later only when a required live-state fact cannot be obtained from an OPNsense page.

### 7.1B-1 GUI service-identity checkpoint

1.  From Kali01, open https://10.10.1.1 and sign in. Confirm the Dashboard still shows LAN 10.10.1.1/24 and WAN 192.168.10.120/24. Capture the Interfaces widget.

2.  Open System \> Diagnostics \> Services. Do not select any start, stop, or restart control. Capture the complete service-status page. If the list is long, use its search field and capture results for unbound, dnsmasq, kea, and dhcp.

3.  Expand the Services menu in the left navigation and capture the available DNS and DHCP entries. The exact menu determines whether the next inventory uses Unbound DNS, Dnsmasq DNS & DHCP, Kea DHCP, or ISC DHCP pages.

4.  Stop and submit the screenshots. Do not open an edit dialog, press Save or Apply, toggle an enable setting, or change a service state.

| **Gate 7.1B-1 pass condition** | **Required evidence**                                                                  |
|--------------------------------|----------------------------------------------------------------------------------------|
| Management continuity          | Dashboard shows the approved LAN and WAN addresses                                     |
| Service identity               | Running/stopped state is visible for Unbound, Dnsmasq, Kea, and ISC DHCP where present |
| Menu inventory                 | Available DNS and DHCP GUI components are visible                                      |
| Scope containment              | No service control or configuration action was used                                    |

| **Recorded result:** PASSED 29 August 2026. The Dashboard preserved WAN 192.168.10.120/24, LAN 10.10.1.1/24, and the approved cyberrange VLAN gateway addresses. System \> Diagnostics \> Services showed Dnsmasq and Unbound active; Kea and ISC DHCP were not active services. The Services menu exposed Dnsmasq DNS & DHCP, Kea DHCP, and Unbound DNS. OpenDNS was disabled. Unbound Query Forwarding contained the enabled existing route polaris.home.arpa to 127.0.0.1 port 53053, which must be preserved. No service control or configuration action was used. |
|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

### 7.1B-2A GUI DNS and DHCP configuration inventory

Remain in the OPNsense web interface from Kali01. Open the pages below only to capture their current state. Do not change a field, select a service control, or press Save or Apply. Query Forwarding has already been captured and does not need to be revisited.

1.  Open Services \> Dnsmasq DNS & DHCP \> General. Capture the top and lower sections so Enable, Listen Port, interfaces or bind settings, and DNS/DHCP behavior are visible.

2.  Open Services \> Dnsmasq DNS & DHCP \> DHCP ranges and capture the complete table. Then capture the complete DHCP options, Domains, and Hosts tables. Empty tables are valid evidence.

3.  Open Services \> Unbound DNS \> General. Capture the top and lower sections so Enable, Listen Port, Network Interfaces, and Outgoing Network Interfaces are visible.

4.  Open Services \> Unbound DNS \> Access Lists and capture the complete table. Empty or automatically generated entries are valid evidence.

5.  Open Services \> Kea DHCP and capture its Settings or landing page, including the Enable control and interface selections. Do not enable or start Kea.

6.  Stop and submit the screenshots. Do not open an edit dialog for any table entry and do not press Save, Apply, start, stop, or restart.

| **Gate 7.1B-2A pass condition** | **Required evidence**                                                           |
|---------------------------------|---------------------------------------------------------------------------------|
| Dnsmasq baseline                | Enable/listen/bind state plus ranges, options, domains, and hosts are visible   |
| Unbound baseline                | Enable/listen/interface state and access lists are visible                      |
| Kea boundary                    | Current disabled state and interface selections are visible                     |
| Existing DNS path               | Previously captured polaris.home.arpa forwarding remains the preserved baseline |
| Scope containment               | No service or configuration control was used                                    |

| **Recorded result:** PASSED 29 August 2026. Dnsmasq was enabled only on LAN at port 53053. Its existing LAN DHCP pool was 10.10.1.41-10.10.1.245; Domains, Hosts, and DHCP Options were empty. Unbound was enabled on port 53 with Network Interfaces and Outgoing Network Interfaces both set to All (recommended), Local Zone Type transparent, Default Access-List Action Allow, and no custom access lists. The Kea Control Agent and Kea DHCPv4 service were disabled; Kea had no selected interfaces or leases. No setting or service state was changed. Remediation finding: the existing LAN pool includes Kali01's static 10.10.1.85, so the overlap must be corrected before another untagged management client can receive a conflicting lease. |
|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

### 7.1B-2B GUI NAT, alias, and firewall-rule inventory

Remain in the OPNsense web interface from Kali01. This is a read-only inventory. Empty tables and disabled rules are valid evidence. Do not press Save or Apply and do not add, edit, clone, delete, enable, or disable any object.

1.  Open Firewall \> NAT \> Outbound. Capture the selected outbound NAT mode and the complete rule table. Expand any automatically generated-rules section and capture all pages if the table is paginated.

2.  Open Firewall \> Aliases. Capture the complete alias table. If aliases are present, capture every page so each alias name, type, and description is visible. Do not open an alias editor yet.

3.  Open Firewall \> Rules \> Floating. Capture the complete floating-rule table, including any automatically generated-rules section.

4.  Under Firewall \> Rules, select and capture the complete rule table for WAN and LAN, followed by CYBER_ATTACK, CYBER_WINDOWS, CYBER_LINUX, CYBER_APPS, CYBER_SIEM, CYBER_ANALYSIS, and CYBER_QUARANTINE. Include each visible tab name and expand any automatically generated-rules section. Empty tables are required evidence, not an error.

5.  Stop and submit the screenshots. Do not press Save or Apply and do not use an add, edit, clone, delete, enable, disable, move, or reorder control.

| **Gate 7.1B-2B pass condition** | **Required evidence**                                                |
|---------------------------------|----------------------------------------------------------------------|
| Outbound NAT baseline           | Selected mode and complete manual/automatic rule tables are visible  |
| Alias baseline                  | Every existing alias name, type, and description is visible          |
| Floating baseline               | Complete floating and automatically generated rule state is visible  |
| Interface baseline              | WAN, LAN, and all seven cyberrange interface rule tables are visible |
| Scope containment               | No NAT, alias, rule, service, DHCP, or DNS control was changed       |

| **Recorded result:** PASSED 29 August 2026. Source NAT remained in Automatic Source NAT rule generation mode with exactly two automatically generated WAN IPv4 rules: a general wildcard rule and its destination-port 500 ISAKMP variant. Both used the aggregated internal-interface network source set and translated to the WAN address; Destination NAT had no entries. The 20-entry alias table included ADMIN01 192.168.10.30, KALI01 10.10.1.85, Proxmox_host 192.168.10.2, DHCP_SERVER port 67, TRUSTED_INFRASTRUCTURE 192.168.10.0/24, RFC1918_NETWORKS 10.0.0.0/8 plus 172.16.0.0/12 plus 192.168.0.0/16, bogon feeds, sshlockout, and automatic interface aliases. The 12 floating automatic rules comprised default deny/state enforcement, IPv6 RFC4890 ICMP requirements, port-zero blocks, sshlockout for ports 22 and 443, virusprot overload handling, and the firewall-host let-out rule. LAN rules allowed DHCP and DNS to OPNsense, allowed KALI01 HTTPS management, blocked other LAN HTTPS management and trusted/RFC1918 destinations, and allowed non-RFC1918 Internet access; the broad default LAN-to-any rule was disabled. WAN rules allowed ADMIN01 HTTPS management and Proxmox_host SSH backup access. All seven CYBER interface rule tables were empty. No NAT, alias, firewall-rule, service, DHCP, or DNS object was changed. |
|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

### 7.1C GUI-only continuity checkpoint

Complete this final pre-change checkpoint without opening an editor or changing configuration. Use the graphical interfaces specified below. If a diagnostic page uses a slightly different menu label, use the OPNsense menu search to open the equivalent Ping or DNS Lookup page.

1.  From Kali01, open https://10.10.1.1 and sign in. On the OPNsense Dashboard, capture the Interfaces widget showing WAN 192.168.10.120/24, LAN 10.10.1.1/24, and the seven approved cyberrange VLAN gateway addresses.

2.  Open System \> Diagnostics \> Services. Use the table search if needed and capture Dnsmasq and Unbound in the running state. Do not select a service control.

3.  Open the OPNsense Ping diagnostic. Select IPv4 and the WAN source or WAN address, then run separate three-probe tests to 192.168.10.2, 192.168.10.1, and 1.1.1.1. Capture each result with zero packet loss. Do not change an interface or gateway setting.

4.  Open the OPNsense DNS Lookup diagnostic and resolve example.com through the default system resolver. Capture a successful answer containing at least one address.

5.  On Kali01, open a new private browser window and load https://example.com. Capture the page with the HTTPS URL visible. This is the end-to-end LAN client check for DNS, firewall policy, automatic Source NAT, and upstream connectivity.

6.  From Admin01, browse to https://192.168.10.120 and sign in to OPNsense. Capture the Dashboard after login to prove the emergency WAN management path remains available. Do not expose credentials in the screenshot.

7.  In the Proxmox web interface, select VM300 and capture Summary showing the VM running. Then open Snapshots and capture post-vlan-interfaces-pre-policy-20260828 in the snapshot tree.

8.  Stop and submit the screenshots. Do not press Save or Apply and do not use a start, stop, restart, add, edit, clone, delete, enable, disable, move, or reorder control.

| **Gate 7.1C pass condition** | **Required evidence**                                                    |
|------------------------------|--------------------------------------------------------------------------|
| Interface continuity         | Dashboard preserves WAN, LAN, and all seven cyberrange gateway addresses |
| Service continuity           | Dnsmasq and Unbound remain running                                       |
| Upstream continuity          | WAN-sourced GUI pings reach peer, gateway, and public IP with zero loss  |
| DNS continuity               | GUI DNS Lookup returns an address for example.com                        |
| Client continuity            | Kali01 loads example.com by HTTPS and Admin01 reaches WAN management     |
| Recovery continuity          | Proxmox shows VM300 running and the pre-policy snapshot present          |
| Scope containment            | No configuration or service control was used                             |

| **Recorded result:** PASSED 30 August 2026. The Dashboard preserved WAN 192.168.10.120/24, LAN 10.10.1.1/24, and all seven approved cyberrange VLAN gateway addresses. Dnsmasq and Unbound remained running. WAN-sourced GUI ping jobs reached 192.168.10.2 with 8/8 replies, 192.168.10.1 with 31/31 replies, and 1.1.1.1 with 7/7 replies; all showed 0.0 percent loss. The GUI DNS Lookup resolved example.com through the local system resolver, Kali01 loaded https://example.com, and Admin01 reached the OPNsense WAN-management Dashboard. Proxmox showed VM300 cyber-fw01 running and the post-vlan-interfaces-pre-policy-20260828 snapshot present. No configuration or service control was used. |
|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

| **Stop condition:** Stop if an approved interface address is missing, Dnsmasq or Unbound is not running, any required ping or DNS lookup fails, Kali01 Internet access or Admin01 emergency management fails, VM300 is not running, the pre-policy snapshot is absent, or any unexpected configuration prompt appears. |
|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

## 7.2A Management DHCP overlap remediation

This is the first controlled configuration change after the Gate 7.1 baseline. It changes only the existing Dnsmasq LAN IPv4 range. The approved replacement pool is 10.10.1.100-10.10.1.199, which excludes Kali01's static 10.10.1.85 address and leaves the remainder of the /24 available for documented static or later approved use. Keep the Proxmox console and Admin01 emergency WAN-management session available throughout the change.

1.  From Kali01, sign in to https://10.10.1.1. Open Services \> Dnsmasq DNS & DHCP \> Leases and capture the complete active-lease table. Stop before making a change if 10.10.1.85 appears as an active lease or if an unknown management client depends on the current range.

2.  Open Services \> Dnsmasq DNS & DHCP \> DHCP ranges. Edit only the existing LAN IPv4 range. Keep the entry enabled and its Interface set to LAN. Change Start address to 10.10.1.100 and End address to 10.10.1.199. Leave Domain, Tags, Subnet Mask, Mode, IPv6 Constructor, Router Advertisement, and all advanced fields unchanged.

3.  Select Save. Review the DHCP-ranges table before applying: it must contain the single LAN range 10.10.1.100-10.10.1.199 and no newly created cyber-VLAN range. If the preview differs, do not apply; reopen the LAN entry and correct only the two addresses.

4.  Select Apply once and wait for the success confirmation. Do not start, stop, or manually restart Dnsmasq or Unbound.

5.  Open System \> Diagnostics \> Services and capture Dnsmasq and Unbound in the running state. Then return to Dnsmasq DHCP ranges and capture the applied 10.10.1.100-10.10.1.199 LAN row.

6.  Open the OPNsense DNS Lookup diagnostic and resolve example.com through the default system resolver. Capture a successful answer containing at least one address.

7.  Return to the Dashboard and capture all approved interface addresses. Confirm Kali01 still reaches https://10.10.1.1 and Admin01 still reaches https://192.168.10.120. Do not expose credentials.

8.  Stop and submit the screenshots. Do not add another DHCP range or change DNS, NAT, aliases, firewall rules, interface bindings, or guest VLAN tags.

| **Gate 7.2A pass condition** | **Required evidence**                                                  |
|------------------------------|------------------------------------------------------------------------|
| Kali01 address correction    | Kali01 is manual static at 10.10.1.85/24 before the pool change        |
| Overlap removed              | Exactly one LAN range is applied at 10.10.1.100-10.10.1.199            |
| Service continuity           | Dnsmasq and Unbound remain running                                     |
| DNS continuity               | GUI DNS Lookup returns an address for example.com                      |
| Management continuity        | Kali01 LAN and Admin01 WAN-management paths remain available           |
| Interface continuity         | WAN, LAN, and all seven cyberrange addresses remain correct            |
| Scope containment            | No other DHCP, DNS, NAT, alias, rule, binding, or VLAN change was made |

| **Recorded result:** PASSED 31 August 2026. The pre-change lease inventory showed Kali01 actively holding 10.10.1.85 as a dynamic lease, which correctly triggered the stop condition. Read-only NetworkManager inspection confirmed that Wired connection 1 was set to Automatic (DHCP), contrary to the approved static management design. Kali01 was corrected to Manual 10.10.1.85/24 with gateway and DNS 10.10.1.1; OPNsense management and HTTPS access to example.com remained available. The single Dnsmasq LAN range was then changed from 10.10.1.41-10.10.1.245 to 10.10.1.100-10.10.1.199 and applied once. Dnsmasq and Unbound remained running, the GUI DNS Lookup resolved example.com through 127.0.0.1, Kali01 retained Internet access, Admin01 retained emergency HTTPS management at 192.168.10.120, and WAN, LAN, and all seven cyberrange gateway addresses remained correct. No cyber-VLAN DHCP range, DNS, NAT, alias, firewall-rule, binding, or VLAN change was made. |
|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

| **Failure action:** Stop if 10.10.1.85 is leased, the old range has an unknown active dependency, Save or Apply reports an error, Dnsmasq or Unbound stops, DNS fails, an interface changes, or either management path is lost. Preserve screenshots and use Admin01 or the Proxmox console only as the recovery path; do not continue into another Gate 7 change. |
|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

| **Gate 7.2C release rule:** Gate 7.2B is approved. Only the Dnsmasq interface selection and seven cyber-VLAN IPv4 ranges are released. OPNsense may automatically register DHCP service firewall rules for the selected interfaces; this expected service behavior does not authorize any manual firewall-rule edit. Stop before Unbound Query Forwarding, reverse DNS, NAT, aliases, or default-deny policy. |
|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

## 7.2B Cyberrange DHCP and DNS design approval

Gate 7.2B is passed. The approved design keeps the cyberrange DNS namespace isolated from firewall01's polaris.home.arpa infrastructure namespace and from the standalone ad.polaris Active Directory namespace. Only the bounded Gate 7.2C Dnsmasq interface and DHCP-range implementation is released in this revision.

| **Design element** | **Approved baseline**                                                                                                               |
|--------------------|-------------------------------------------------------------------------------------------------------------------------------------|
| IPv4 DHCP pools    | .100-.199 pools on VLANs 10, 20, 30, 40, 50, 60, and 99                                                                             |
| Default gateways   | The corresponding OPNsense .1 interface address for each /24                                                                        |
| DNS service path   | Preserve Dnsmasq-to-Unbound; add zone forwarding only in a later gate                                                               |
| DNS namespace      | Zone-specific subdomains beneath cyberrange.home.arpa; never reuse ad.polaris or expand infrastructure records in polaris.home.arpa |
| IPv6               | Remain unused/disabled; no DHCPv6 or router advertisements                                                                          |
| Quarantine         | May receive an isolated address but must retain no upstream or cross-zone access                                                    |

| **Approved decision:** PASSED 31 August 2026. Use attack.cyberrange.home.arpa, windows.cyberrange.home.arpa, linux.cyberrange.home.arpa, apps.cyberrange.home.arpa, siem.cyberrange.home.arpa, analysis.cyberrange.home.arpa, and quarantine.cyberrange.home.arpa. This namespace is independent of firewall01's polaris.home.arpa and the standalone Active Directory namespace ad.polaris. |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

## 7.2C Dnsmasq cyber-VLAN DHCP range implementation

This gate creates the approved IPv4 address-delivery baseline without attaching a guest or releasing general traffic. The domain on each range is the DHCP-provided zone suffix. Unbound forwarding for those domains and their reverse zones is intentionally deferred.

| **Interface**    | **VLAN** | **IPv4 range**            | **Domain**                      |
|------------------|----------|---------------------------|---------------------------------|
| CYBER_ATTACK     | 10       | 10.10.10.100-10.10.10.199 | attack.cyberrange.home.arpa     |
| CYBER_WINDOWS    | 20       | 10.10.20.100-10.10.20.199 | windows.cyberrange.home.arpa    |
| CYBER_LINUX      | 30       | 10.10.30.100-10.10.30.199 | linux.cyberrange.home.arpa      |
| CYBER_APPS       | 40       | 10.10.40.100-10.10.40.199 | apps.cyberrange.home.arpa       |
| CYBER_SIEM       | 50       | 10.10.50.100-10.10.50.199 | siem.cyberrange.home.arpa       |
| CYBER_ANALYSIS   | 60       | 10.10.60.100-10.10.60.199 | analysis.cyberrange.home.arpa   |
| CYBER_QUARANTINE | 99       | 10.10.99.100-10.10.99.199 | quarantine.cyberrange.home.arpa |

1.  From Kali01, sign in to https://10.10.1.1. Keep the Admin01 emergency session and Proxmox console available. Open Services \> Dnsmasq DNS & DHCP \> General.

2.  Edit only Interface. Preserve LAN and add CYBER_ATTACK, CYBER_WINDOWS, CYBER_LINUX, CYBER_APPS, CYBER_SIEM, CYBER_ANALYSIS, and CYBER_QUARANTINE. Leave Enable, Listen Port 53053, strict binding, DHCP FQDN/default-domain behavior, DHCPv6, router advertisements, and every other field unchanged. Select Save; do not Apply yet.

3.  Open DHCP ranges. Preserve the existing LAN 10.10.1.100-10.10.1.199 row. Add the seven enabled IPv4 ranges exactly as mapped above. For each, select its interface, enter its start and end address, enter its approved Domain, leave Domain Type and all advanced/IPv6 fields unchanged, and select Save.

4.  Before applying, verify the table contains exactly eight rows: the unchanged LAN row plus the seven cyber rows. Verify that no start/end address, interface, or domain is duplicated or assigned to the wrong VLAN. If any field differs, stop and correct the pending change.

5.  Select Apply once. Wait for success. Do not manually start, stop, or restart Dnsmasq or Unbound.

6.  Capture the complete applied DHCP-ranges table and Dnsmasq General interface selection. Then capture System \> Diagnostics \> Services with Dnsmasq and Unbound running.

7.  Run the GUI DNS Lookup for example.com through the default resolver, confirm Kali01 still loads https://example.com and https://10.10.1.1, and confirm Admin01 still reaches https://192.168.10.120. Stop and submit the evidence.

| **Gate 7.2C pass condition** | **Required evidence**                                                 |
|------------------------------|-----------------------------------------------------------------------|
| Interface scope              | LAN plus all seven approved cyber interfaces are selected             |
| Range inventory              | Exactly eight ranges: unchanged LAN plus seven approved cyber ranges  |
| Namespace mapping            | Every cyber range uses its approved zone-specific subdomain           |
| Service continuity           | Dnsmasq and Unbound remain running                                    |
| DNS/client continuity        | GUI lookup and Kali01 Internet access remain successful               |
| Management continuity        | Kali01 LAN and Admin01 WAN-management paths remain available          |
| Scope containment            | No Unbound forwarding, manual rule, NAT, alias, IPv6, or guest change |

| **Recorded result:** PASSED 1 September 2026. Dnsmasq retained LAN and added CYBER_ATTACK, CYBER_WINDOWS, CYBER_LINUX, CYBER_APPS, CYBER_SIEM, CYBER_ANALYSIS, and CYBER_QUARANTINE. The applied table contained exactly eight IPv4 ranges: the preserved LAN 10.10.1.100-10.10.1.199 row and the seven approved .100-.199 cyber pools with their zone-specific subdomains beneath cyberrange.home.arpa. Dnsmasq retained port 53053, DHCP FQDN, DHCP local-domain behavior, and the existing polaris.home.arpa default domain. Dnsmasq and Unbound remained running; the GUI DNS Lookup resolved example.com through 127.0.0.1; Kali01 retained OPNsense and Internet access; and Admin01 retained emergency HTTPS management at 192.168.10.120. No Unbound forwarding, manual firewall-rule, NAT, alias, IPv6, or guest change was made. |
|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

| **Failure action:** Stop if the range preview is not exact, Save or Apply reports an error, either DNS service stops, DNS or Internet validation fails, an interface address changes, or either management path is lost. Use Admin01 or the Proxmox console only as the recovery path. Do not continue to Unbound forwarding or firewall policy. |
|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

| **Gate 7.2D release rule:** Gate 7.2C is passed. Preserve the existing polaris.home.arpa forwarding entry and add only the fourteen approved forward/reverse entries to 127.0.0.1 port 53053. Stop before any firewall, NAT, alias, guest, or broader DNS change. |
|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

## 7.2D Unbound forwarding for cyberrange DHCP zones

Unbound remains the client-facing resolver on port 53. This gate forwards only the approved cyberrange DHCP namespaces and their /24 reverse zones to Dnsmasq on 127.0.0.1:53053. The parent cyberrange.home.arpa zone is not forwarded, which keeps each approved zone explicit.

| **Type** | **Domain**                      | **Server IP** | **Port** |
|----------|---------------------------------|---------------|----------|
| Forward  | attack.cyberrange.home.arpa     | 127.0.0.1     | 53053    |
| Forward  | windows.cyberrange.home.arpa    | 127.0.0.1     | 53053    |
| Forward  | linux.cyberrange.home.arpa      | 127.0.0.1     | 53053    |
| Forward  | apps.cyberrange.home.arpa       | 127.0.0.1     | 53053    |
| Forward  | siem.cyberrange.home.arpa       | 127.0.0.1     | 53053    |
| Forward  | analysis.cyberrange.home.arpa   | 127.0.0.1     | 53053    |
| Forward  | quarantine.cyberrange.home.arpa | 127.0.0.1     | 53053    |
| Reverse  | 10.10.10.in-addr.arpa           | 127.0.0.1     | 53053    |
| Reverse  | 20.10.10.in-addr.arpa           | 127.0.0.1     | 53053    |
| Reverse  | 30.10.10.in-addr.arpa           | 127.0.0.1     | 53053    |
| Reverse  | 40.10.10.in-addr.arpa           | 127.0.0.1     | 53053    |
| Reverse  | 50.10.10.in-addr.arpa           | 127.0.0.1     | 53053    |
| Reverse  | 60.10.10.in-addr.arpa           | 127.0.0.1     | 53053    |
| Reverse  | 99.10.10.in-addr.arpa           | 127.0.0.1     | 53053    |

8.  From Kali01, open Services \> Unbound DNS \> Query Forwarding. Capture the complete table without selecting Add, Edit, Delete, Save, or Apply. The expected baseline is one enabled polaris.home.arpa entry to 127.0.0.1 port 53053. Stop and submit the table if it differs.

9.  After the baseline is confirmed, preserve the existing entry and add the seven Forward rows exactly as mapped above. Leave optional fields at their defaults. Select Save after each row but do not Apply.

10. Add the seven Reverse rows exactly as mapped above, again using 127.0.0.1 and port 53053. Select Save after each row but do not Apply.

11. Before applying, verify exactly fifteen enabled entries: the unchanged polaris.home.arpa entry plus fourteen new rows. Confirm there is no parent cyberrange.home.arpa entry, no duplicate, and no ad.polaris entry. Stop and correct any pending discrepancy.

12. Select Apply once and wait for success. Do not manually restart Unbound or Dnsmasq.

13. Capture the complete applied Query Forwarding table, System \> Diagnostics \> Services with Unbound and Dnsmasq running, and a successful GUI DNS Lookup for example.com. Confirm Kali01 and Admin01 management paths remain available, then stop and submit the evidence.

| **Gate 7.2D pass condition** | **Required evidence**                                          |
|------------------------------|----------------------------------------------------------------|
| Preserved baseline           | Existing polaris.home.arpa -\> 127.0.0.1:53053 remains enabled |
| Forward zones                | Exactly seven approved cyberrange subdomains are forwarded     |
| Reverse zones                | Exactly seven approved /24 reverse zones are forwarded         |
| Entry inventory              | Exactly fifteen enabled rows; no parent or duplicate zone      |
| Service continuity           | Unbound and Dnsmasq remain running                             |
| DNS/client continuity        | Public DNS and Kali01 Internet access remain successful        |
| Management continuity        | Kali01 LAN and Admin01 WAN-management paths remain available   |
| Scope containment            | No Dnsmasq, firewall, NAT, alias, IPv6, or guest change        |

| **Recorded result:** PASSED 1 September 2026. The existing enabled polaris.home.arpa entry remained unchanged at 127.0.0.1:53053. Seven approved cyberrange forward zones and seven approved /24 reverse zones were added, producing exactly fifteen enabled Query Forwarding entries with no parent cyberrange.home.arpa entry, no ad.polaris entry, and no duplicate. Use System Nameservers remained unchecked. Unbound and Dnsmasq remained running; the GUI DNS Lookup resolved example.com through 127.0.0.1; Kali01 retained Internet and OPNsense access at 10.10.1.1; and Admin01 retained emergency HTTPS management at 192.168.10.120. |
|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

| **Failure action:** Stop if the baseline differs, a forwarding row is not exact, Save or Apply reports an error, either DNS service stops, public DNS fails, or either management path is lost. Use Admin01 or the Proxmox console only as the recovery path; do not continue into policy work. |
|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

| **Gate 7.3A release rule:** Gate 7.2D is passed. Capture only the current LAN and seven CYBER Firewall \> Rules tables. Do not re-inventory the frozen alias or NAT baselines and do not change any rule or setting. |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

## 7.3A Read-only post-DNS firewall-rule inventory

Dnsmasq registers automatic firewall rules for interfaces that serve DHCP ranges. This checkpoint records the visible post-DNS rule state on the eight selected interfaces before Project Polaris creates any aliases or manual isolation policy. The passed Gate 7.1B-2 alias and outbound-NAT inventories remain frozen and are not repeated.

14. From Kali01, open Firewall \> Rules. Do not select Add, Edit, Delete, Clone, Move, Enable, Disable, Save, Apply, or any bulk-action control.

15. Capture the complete LAN rule table. If the table is wider than the browser window, zoom out only enough to show Action, Protocol, Source, Source Port, Destination, Destination Port, Gateway, Schedule, and Description.

16. Capture the complete rule table for CYBER_ATTACK, CYBER_WINDOWS, CYBER_LINUX, CYBER_APPS, CYBER_SIEM, CYBER_ANALYSIS, and CYBER_QUARANTINE. Use the 50-row view when offered and capture additional screenshots if any table cannot fit in one image.

17. Stop and submit all eight interface tables. Do not create aliases, add default-deny rules, change NAT, or attach a guest until the inventory is reviewed.

| **Gate 7.3A pass condition** | **Required evidence**                                            |
|------------------------------|------------------------------------------------------------------|
| LAN inventory                | Complete current LAN rule table is readable                      |
| Cyber inventories            | Complete tables for all seven CYBER interfaces are readable      |
| Automatic-rule visibility    | Any generated DHCP/DNS rules are captured exactly as displayed   |
| Manual-policy baseline       | No unapproved manual cyberrange pass or block rule is present    |
| Scope containment            | No firewall, NAT, alias, DNS/DHCP, IPv6, or guest change is made |

| **Recorded result:** PASSED 1 September 2026. LAN displayed thirty-one total rules: the automatic rules plus the established DHCP, DNS, Kali01 management, OPNsense-management block, trusted-infrastructure block, RFC1918 block, and non-RFC1918 Internet-access interface rules; the broad default LAN to any rule remained disabled. Each of CYBER_ATTACK, CYBER_WINDOWS, CYBER_LINUX, CYBER_APPS, CYBER_SIEM, CYBER_ANALYSIS, and CYBER_QUARANTINE displayed the same twenty automatic rules, including default-deny/state handling, IPv6 control traffic, virusprot, DHCPv4/DHCPv6 access, and firewall-host egress. Every cyber tab reported that no interface rules were defined. No manual cyber pass or block rule and no configuration change was present. |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

| **Failure action:** Stop if any table is incomplete, a row cannot be identified, an unexpected manual cyber rule is present, or any configuration-control action is selected. Make no correction during this checkpoint; submit the evidence for review. |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

| **Gate 7.3B release rule:** Gate 7.3A is passed. Review the proposed no-new-alias, per-interface, default-closed policy design. Do not create or apply any rule until the design is explicitly approved. |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

## 7.3B Default-closed cyber policy design approval

The current alias inventory already supplies RFC1918_NETWORKS, KALI01, ADMIN01, Proxmox_host, DHCP_SERVER, and OPNsense's automatic interface-network objects. Creating overlapping aliases would add drift without improving enforcement. The recommended design therefore creates no alias in this gate and uses explicit per-interface rules. Automatic rules remain ahead of manual interface rules; manual quick rules are evaluated top to bottom.

| **Order** | **Action**  | **Version/protocol** | **Source**    | **Destination**  | **Port**    | **Purpose**                                          |
|-----------|-------------|----------------------|---------------|------------------|-------------|------------------------------------------------------|
| 1         | Pass        | IPv4 TCP/UDP         | Interface net | This Firewall    | domain (53) | Allow DNS to OPNsense; omit on CYBER_QUARANTINE      |
| 2         | Block + log | IPv4 any             | Interface net | This Firewall    | any         | Block OPNsense control-plane access                  |
| 3         | Block + log | IPv4 any             | Interface net | RFC1918_NETWORKS | any         | Block private upstream and inter-zone access         |
| Default   | Deny        | IPv4/IPv6            | any           | any              | any         | No baseline Internet, cross-zone, or upstream access |

The three manual rules would be identical on CYBER_ATTACK, CYBER_WINDOWS, CYBER_LINUX, CYBER_APPS, CYBER_SIEM, and CYBER_ANALYSIS. CYBER_QUARANTINE would omit the DNS pass rule and retain only the explicit control-plane and RFC1918 blocks plus implicit default deny. No broad Internet rule is included. Future scenario-specific attack-to-target, target-to-SIEM, or time-bounded Internet rules must be separately authorized and placed above the blocks.

| **Gate 7.3B decision** | **Recommended design**                                                  |
|------------------------|-------------------------------------------------------------------------|
| Alias strategy         | Reuse existing aliases and automatic interface objects; create none     |
| Rule scope             | Per-interface rules; no interface group or floating policy              |
| DNS exception          | Allow TCP/UDP 53 to This Firewall on six active-purpose zones           |
| Quarantine             | No DNS exception and no permitted upstream path                         |
| Management             | Explicit logged block to This Firewall below any DNS exception          |
| Private/inter-zone     | Explicit logged block to RFC1918_NETWORKS                               |
| Internet               | No baseline allow rule; later authorization required                    |
| IPv6                   | No manual IPv6 pass rule; existing disabled/unavailable posture remains |

| **Recorded decision:** APPROVED 1 September 2026. Reuse the existing aliases and OPNsense automatic interface objects; create no overlapping alias. Use explicit per-interface IPv4 rules, allow DNS to This Firewall on the six active-purpose cyber zones, omit DNS on CYBER_QUARANTINE, block and log control-plane access, block and log RFC1918 private/inter-zone access, add no baseline Internet pass, and add no manual IPv6 pass. Future scenario exceptions require separate approval. |
|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

| **Gate 7.3C-1 recorded result:** PASSED 2 September 2026. The CYBER_ANALYSIS table showed twenty automatic rules plus exactly three enabled pending interface rules in the approved order: IPv4 TCP/UDP DNS pass from CYBER_ANALYSIS net to This Firewall port domain; logged IPv4 control-plane block to This Firewall; and logged IPv4 private/inter-zone block to RFC1918_NETWORKS. The Apply reminder remained present, confirming the rules had not entered runtime. |
|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

## 7.3C-1 CYBER_ANALYSIS pending rule-template build

CYBER_ANALYSIS has no guest and no operational flow, making it the controlled template interface. This checkpoint stages three manual quick rules beneath the automatic rules. Saving each row updates the pending configuration only; Apply remains a separate checkpoint.

| **Order** | **Action** | **IP** | **Protocol** | **Source**         | **Src port** | **Destination**  | **Dst port** | **Log** | **Description**                       |
|-----------|------------|--------|--------------|--------------------|--------------|------------------|--------------|---------|---------------------------------------|
| 1         | Pass       | IPv4   | TCP/UDP      | CYBER_ANALYSIS net | any          | This Firewall    | domain (53)  | No      | Allow DNS to OPNsense                 |
| 2         | Block      | IPv4   | any          | CYBER_ANALYSIS net | any          | This Firewall    | any          | Yes     | Block OPNsense control plane          |
| 3         | Block      | IPv4   | any          | CYBER_ANALYSIS net | any          | RFC1918_NETWORKS | any          | Yes     | Block private and inter-zone networks |

18. From Kali01, open Firewall \> Rules \> CYBER_ANALYSIS. Confirm the banner still states that no CYBER_ANALYSIS interface rules are defined. Do not alter the automatic rules.

19. Select Add. Create rule 1 exactly as mapped: Action Pass; Quick enabled; Interface CYBER_ANALYSIS; Direction in; TCP/IP Version IPv4; Protocol TCP/UDP; Source CYBER_ANALYSIS net with any source port; Destination This Firewall with destination port domain (53); logging disabled; Gateway default; Schedule none; description Allow DNS to OPNsense. Select Save, but do not Apply.

20. Select Add. Create rule 2 exactly as mapped: Action Block; Quick enabled; Interface CYBER_ANALYSIS; Direction in; TCP/IP Version IPv4; Protocol any; Source CYBER_ANALYSIS net with any source port; Destination This Firewall with any destination port; logging enabled; Gateway default; Schedule none; description Block OPNsense control plane. Select Save, but do not Apply.

21. Select Add. Create rule 3 exactly as mapped: Action Block; Quick enabled; Interface CYBER_ANALYSIS; Direction in; TCP/IP Version IPv4; Protocol any; Source CYBER_ANALYSIS net with any source port; Destination RFC1918_NETWORKS with any destination port; logging enabled; Gateway default; Schedule none; description Block private and inter-zone networks. Select Save, but do not Apply.

22. Before applying, verify exactly three enabled CYBER_ANALYSIS interface rules in the order DNS pass, control-plane block, RFC1918 block. Capture the complete table showing automatic and interface sections, then stop and submit the evidence.

| **Gate 7.3C-1 pending condition** | **Required evidence**                                           |
|-----------------------------------|-----------------------------------------------------------------|
| Scope                             | Only CYBER_ANALYSIS has pending manual rules                    |
| Rule count                        | Exactly three enabled interface rules                           |
| Order                             | DNS pass, This Firewall block, RFC1918_NETWORKS block           |
| Logging                           | Disabled on DNS pass; enabled on both block rules               |
| Runtime                           | Apply has not been selected                                     |
| Containment                       | No alias, NAT, DNS/DHCP, IPv6, guest, or other-interface change |

## 7.3C-2 CYBER_ANALYSIS apply and continuity validation

This checkpoint activates only the three already-staged CYBER_ANALYSIS rules. Because the interface has no guest or operational flow, the immediate acceptance criteria are rule-table integrity, successful configuration activation, and uninterrupted access through both approved management paths. Behavioral traffic testing remains a later controlled-guest gate.

23. From Kali01 at https://10.10.1.1, remain on Firewall \> Rules \> CYBER_ANALYSIS. Confirm the pending table still shows twenty automatic rules plus the same three enabled interface rules in the approved order. Do not edit any field.

24. Select Apply exactly once. Wait for OPNsense to report successful application. Do not select Apply again, refresh during processing, or navigate to another configuration page.

25. After processing completes, refresh Firewall \> Rules \> CYBER_ANALYSIS. Confirm the pending-change reminder is absent and the table still shows twenty automatic rules plus three enabled interface rules in the order DNS pass, This Firewall block, and RFC1918_NETWORKS block.

26. From Kali01, open https://10.10.1.1 in a new tab and confirm the OPNsense GUI loads normally. Do not change the established LAN management policy.

27. From Admin01, open https://192.168.10.120 and confirm the approved WAN emergency-management path still loads the OPNsense GUI. Do not modify WAN policy.

28. Capture the post-Apply CYBER_ANALYSIS table and evidence of both successful management paths, then stop. Do not clone the rules or begin CYBER_QUARANTINE.

| **Gate 7.3C-2 pass condition** | **Required evidence**                                                        |
|--------------------------------|------------------------------------------------------------------------------|
| Activation                     | Apply completed once with no reported error                                  |
| Pending state                  | The pending-change reminder is absent                                        |
| Rule count                     | Twenty automatic rules plus exactly three enabled interface rules            |
| Rule integrity                 | DNS pass, This Firewall block, RFC1918_NETWORKS block; values unchanged      |
| Primary management             | Kali01 reaches the GUI at https://10.10.1.1                                  |
| Emergency management           | Admin01 reaches the GUI at https://192.168.10.120                            |
| Containment                    | No edit, clone, alias, NAT, DNS/DHCP, IPv6, guest, or other-interface change |

| **Gate 7.3C-2 recorded result:** PASSED 2 September 2026. Apply completed successfully; the pending-change reminder was absent; the CYBER_ANALYSIS table remained at twenty automatic rules plus the three enabled interface rules in the approved order; Kali01 retained primary management at https://10.10.1.1; and Admin01 retained emergency management at https://192.168.10.120. No other rule, interface, alias, NAT, DNS/DHCP, IPv6, guest, or service change was made. |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

## 7.3C-3 Post-apply configuration recovery export

This recovery-first checkpoint captures the newly active CYBER_ANALYSIS policy before any copying to other zones. It is an export-and-validate operation only; it does not authorize restoration, configuration-history changes, or any additional firewall work.

29. From Kali01 at https://10.10.1.1, open System \> Configuration \> Backups (or the equivalent OPNsense configuration-backup page). Use the current running configuration only.

30. Download a fresh configuration XML to Kali01. Do not restore, revert, edit, or select a historical configuration.

31. On Kali01, open a terminal and run the following block exactly. It selects the newest XML in Downloads, proves it is non-empty, records its SHA-256 digest, validates one OPNsense root element, and confirms the activated CYBER_ANALYSIS policy is represented.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>config_file="$(find "$HOME/Downloads" -maxdepth 1 -type f -name '*.xml' -printf '%T@ %p\n' | sort -nr | head -n 1 | cut -d' ' -f2-)"<br />
test -n "$config_file" &amp;&amp; test -s "$config_file"<br />
printf 'FILE=%s\n' "$config_file"<br />
stat --printf='SIZE=%s\n' "$config_file"<br />
sha256sum "$config_file"<br />
grep -c '&lt;opnsense' "$config_file"<br />
grep -ci 'CYBER_ANALYSIS' "$config_file"<br />
grep -ci 'Allow DNS to OPNsense' "$config_file"<br />
grep -ci 'Block OPNsense Control Plane' "$config_file"<br />
grep -ci 'Block Private and Inter-Zone Networks' "$config_file"<br />
grep -ci 'RFC1918_NETWORKS' "$config_file"</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

32. Confirm the terminal reports a file path, a positive byte size, a SHA-256 digest, exactly one \<opnsense root occurrence, and a count of at least one for CYBER_ANALYSIS, each of the three rule descriptions, and RFC1918_NETWORKS.

33. Capture the backup-page state and the complete terminal output showing filename, size, digest, and counts. Submit that evidence and stop.

| **Gate 7.3C-3 pass condition** | **Required evidence**                                                                                 |
|--------------------------------|-------------------------------------------------------------------------------------------------------|
| Fresh export                   | A newly downloaded, non-empty current-configuration XML                                               |
| Root validation                | The \<opnsense search returns exactly 1                                                               |
| Integrity record               | Filename, positive size, and SHA-256 digest are recorded                                              |
| Policy presence                | CYBER_ANALYSIS, all three rule descriptions, and RFC1918_NETWORKS each return at least 1              |
| Containment                    | No restore, history edit, rule clone/edit/Apply, alias, NAT, DNS/DHCP, IPv6, guest, or service change |

| **Gate 7.3C-3 recorded result:** PASSED 2 September 2026. Kali01 downloaded the fresh 99,998-byte current-configuration XML config-OPNsense01.polaris.home.arpa-20260902112716.xml. Its SHA-256 digest is 85b266d8cc39ab2d8edb6fbe21d3a120e060f72f3f93eb886c011541033dc0da. Validation returned one OPNsense root occurrence; counts of 2 for CYBER_ANALYSIS and Allow DNS to OPNsense; counts of 1 for Block OPNsense Control Plane and Block Private and Inter-Zone Networks; and a count of 4 for RFC1918_NETWORKS. No restore, history edit, firewall, alias, NAT, DNS/DHCP, IPv6, guest, or service change was made. |
|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

## 7.3C-4 Stage five active-purpose interface rule sets

This checkpoint performs a mechanical, pending-only expansion of the already active CYBER_ANALYSIS template. Each clone must retain the source rule's action, IP version, protocol, destination, destination port, logging, gateway, schedule, and description. Only Interface and Source change to the selected target interface.

| **Target Interface** | **Required Source** |
|----------------------|---------------------|
| CYBER_ATTACK         | CYBER_ATTACK net    |
| CYBER_WINDOWS        | CYBER_WINDOWS net   |
| CYBER_LINUX          | CYBER_LINUX net     |
| CYBER_APPS           | CYBER_APPS net      |
| CYBER_SIEM           | CYBER_SIEM net      |

| **Order** | **Action / protocol** | **Destination**             | **Log** | **Description**                       |
|-----------|-----------------------|-----------------------------|---------|---------------------------------------|
| 1         | Pass / IPv4 TCP/UDP   | This Firewall / domain (53) | No      | Allow DNS to OPNsense                 |
| 2         | Block / IPv4 any      | This Firewall / any         | Yes     | Block OPNsense Control Plane          |
| 3         | Block / IPv4 any      | RFC1918_NETWORKS / any      | Yes     | Block Private and Inter-Zone Networks |

34. From Kali01 at https://10.10.1.1, open Firewall \> Rules \> CYBER_ANALYSIS. Confirm the source table still contains twenty automatic rules plus the three active interface rules in the approved order. Do not edit the source rules.

35. Process the target interfaces one at a time in the table order above. For the selected target, return to CYBER_ANALYSIS and use Clone on rule 1. Change Interface to the target interface and Source to that target's interface net. Change no other field. Select Save, but do not Apply.

36. Return to CYBER_ANALYSIS and clone rule 2 to the same target. Change only Interface and Source to the target values, confirm logging remains enabled, and select Save without Apply.

37. Return to CYBER_ANALYSIS and clone rule 3 to the same target. Change only Interface and Source to the target values, confirm destination RFC1918_NETWORKS and logging enabled, and select Save without Apply.

38. Open the target interface rule table. Confirm the pending-change reminder is present and the table shows twenty automatic rules plus exactly three enabled interface rules in the order DNS pass, This Firewall block, and RFC1918_NETWORKS block. Compare every visible value to the mapping above before continuing to the next target.

39. Repeat the three-clone and inspection sequence for CYBER_ATTACK, CYBER_WINDOWS, CYBER_LINUX, CYBER_APPS, and CYBER_SIEM. Never clone a previously cloned target rule; every clone must originate from the corresponding CYBER_ANALYSIS source rule.

40. After all five target tables pass inspection, reopen CYBER_ANALYSIS and confirm its three source rules remain unchanged. Open CYBER_QUARANTINE and confirm it still has twenty automatic rules and no interface rules.

41. Capture the complete pending rule table for each of the five target interfaces, the unchanged CYBER_ANALYSIS table, and the automatic-only CYBER_QUARANTINE table. Stop and submit the evidence. Do not select Apply.

| **Gate 7.3C-4 pass condition** | **Required evidence**                                                                    |
|--------------------------------|------------------------------------------------------------------------------------------|
| Target scope                   | Only CYBER_ATTACK, CYBER_WINDOWS, CYBER_LINUX, CYBER_APPS, and CYBER_SIEM receive clones |
| Rule count                     | Each target shows twenty automatic plus exactly three enabled interface rules            |
| Order                          | DNS pass, This Firewall block, RFC1918_NETWORKS block                                    |
| Source binding                 | Every target rule uses that target's own interface net                                   |
| Rule integrity                 | All non-Interface and non-Source fields match the CYBER_ANALYSIS source rule             |
| Template integrity             | CYBER_ANALYSIS remains unchanged at twenty automatic plus three active interface rules   |
| Quarantine integrity           | CYBER_QUARANTINE remains automatic-only with no interface rules                          |
| Pending state                  | The pending-change reminder remains present; Apply is not selected                       |
| Containment                    | No alias, NAT, DNS/DHCP, IPv6, guest, service, automatic-rule, or other-interface change |

| **Gate 7.3C-4 recorded result:** PASSED 2 September 2026. Screenshots verified CYBER_ATTACK, CYBER_WINDOWS, CYBER_LINUX, CYBER_APPS, and CYBER_SIEM each at twenty automatic rules plus exactly three enabled, pending interface rules in the approved order. Every target rule used its own interface and interface network as Source; destinations, services, descriptions, actions, and logging matched the CYBER_ANALYSIS template. CYBER_ANALYSIS remained unchanged at twenty automatic plus three active interface rules. CYBER_QUARANTINE remained at twenty automatic rules with no interface rules. The global pending-change reminder remained present and Apply was not selected. |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

## 7.3C-5 Activate five staged rule sets and validate continuity

OPNsense presents the pending firewall work as one global changeset, including on the automatic-only CYBER_QUARANTINE page. This checkpoint authorizes one Apply operation for the already-inspected fifteen cloned rules only. It does not authorize any additional edit or the later CYBER_QUARANTINE rule pair.

42. From Kali01 at https://10.10.1.1, open Firewall \> Rules \> CYBER_ANALYSIS. Confirm the pending-change reminder is still present. Do not edit any rule.

43. Select Apply exactly once. Wait for OPNsense to report successful application. Do not select Apply again, refresh during processing, navigate away, or make another configuration change.

44. After processing completes, refresh Firewall \> Rules \> CYBER_ANALYSIS. Confirm the pending-change reminder is absent and the table still shows twenty automatic rules plus the three enabled interface rules in the approved order.

45. Open CYBER_ATTACK, CYBER_WINDOWS, CYBER_LINUX, CYBER_APPS, and CYBER_SIEM one at a time. For each table, confirm the pending reminder is absent; the count is twenty automatic plus three enabled interface rules; the order is DNS pass, This Firewall block, and RFC1918_NETWORKS block; and every Source remains that interface's own network.

46. Open CYBER_QUARANTINE. Confirm the pending reminder is absent and the table still contains twenty automatic rules with no interface rules. Do not add the later quarantine rule pair.

47. From Kali01, open https://10.10.1.1 in a new tab and confirm the primary OPNsense management path loads normally. Do not change LAN policy.

48. From Admin01, open https://192.168.10.120 and confirm the approved WAN emergency-management path still loads the OPNsense GUI. Do not change WAN policy.

49. Capture the post-Apply tables for all seven cyber interfaces, evidence that the pending reminder is absent, and evidence of both successful management paths. Submit the evidence and stop; do not begin CYBER_QUARANTINE rule creation.

| **Gate 7.3C-5 pass condition** | **Required evidence**                                                                               |
|--------------------------------|-----------------------------------------------------------------------------------------------------|
| Activation                     | Apply completes exactly once with no reported error                                                 |
| Pending state                  | The pending-change reminder is absent after refresh                                                 |
| Active-purpose count           | Each of six active-purpose tables shows twenty automatic plus three enabled interface rules         |
| Order and binding              | Each active-purpose table retains approved order and its own interface-network Source               |
| Quarantine integrity           | CYBER_QUARANTINE remains at twenty automatic rules and no interface rules                           |
| Primary management             | Kali01 reaches the GUI at https://10.10.1.1                                                         |
| Emergency management           | Admin01 reaches the GUI at https://192.168.10.120                                                   |
| Containment                    | No rule edit, second Apply, alias, NAT, DNS/DHCP, IPv6, guest, service, WAN/LAN, or upstream change |

| **Gate 7.3C-5 recorded result:** PASSED 2 September 2026. The operator confirmed that Apply completed once without error, the global pending-change reminder cleared, and all seven cyber interface tables passed inspection. Each of the six active-purpose interfaces retained twenty automatic rules plus three enabled interface rules in the approved order with its own interface network as Source. Supporting post-Apply evidence showed CYBER_WINDOWS at twenty-three total entries with the correct DNS pass, This Firewall block, and RFC1918_NETWORKS block. CYBER_QUARANTINE remained at twenty automatic rules with no interface rules. Kali01 retained primary management at https://10.10.1.1 and Admin01 retained emergency management at https://192.168.10.120. No additional rule, alias, NAT, DNS/DHCP, IPv6, guest, service, WAN/LAN, or upstream change was made. |
|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

## 7.3C-6 Stage CYBER_QUARANTINE block-only rule pair

CYBER_QUARANTINE must receive DHCP through OPNsense's existing automatic service rules while receiving no manual DNS exception, management access, private/inter-zone access, Internet access, or other upstream path. Its manual baseline therefore contains only the two logged IPv4 block rules below, followed by implicit default deny.

| **Order** | **Action / protocol**  | **Source**           | **Destination**        | **Description**                       |
|-----------|------------------------|----------------------|------------------------|---------------------------------------|
| 1         | Block + log / IPv4 any | CYBER_QUARANTINE net | This Firewall / any    | Block OPNsense Control Plane          |
| 2         | Block + log / IPv4 any | CYBER_QUARANTINE net | RFC1918_NETWORKS / any | Block Private and Inter-Zone Networks |

50. From Kali01 at https://10.10.1.1, open Firewall \> Rules \> CYBER_ANALYSIS. Confirm its table has no pending reminder and still contains twenty automatic rules plus the three active interface rules in the approved order. Do not edit a source rule.

51. Use Clone on the second CYBER_ANALYSIS interface rule, Block OPNsense Control Plane. Change Interface to CYBER_QUARANTINE and Source to CYBER_QUARANTINE net. Change no other field; confirm IPv4, protocol any, destination This Firewall, logging enabled, and the unchanged description. Select Save, but do not Apply.

52. Return to CYBER_ANALYSIS and use Clone on the third interface rule, Block Private and Inter-Zone Networks. Change Interface to CYBER_QUARANTINE and Source to CYBER_QUARANTINE net. Change no other field; confirm IPv4, protocol any, destination RFC1918_NETWORKS, logging enabled, and the unchanged description. Select Save, but do not Apply.

53. Open Firewall \> Rules \> CYBER_QUARANTINE. Confirm the pending-change reminder is present and the table shows twenty automatic rules plus exactly two enabled interface rules in this order: This Firewall block, then RFC1918_NETWORKS block. Confirm there is no DNS pass rule.

54. Reopen CYBER_ANALYSIS and confirm its three active source rules remain unchanged. Verify CYBER_ATTACK, CYBER_WINDOWS, CYBER_LINUX, CYBER_APPS, and CYBER_SIEM remain at twenty automatic plus three active interface rules each. Do not edit any table.

55. Capture the complete pending CYBER_QUARANTINE table and the unchanged CYBER_ANALYSIS table. Submit the evidence and stop. Do not select Apply.

| **Gate 7.3C-6 pass condition** | **Required evidence**                                                                                 |
|--------------------------------|-------------------------------------------------------------------------------------------------------|
| Rule count                     | CYBER_QUARANTINE shows twenty automatic plus exactly two enabled interface rules                      |
| Order                          | This Firewall block followed by RFC1918_NETWORKS block                                                |
| Source binding                 | Both manual rules use CYBER_QUARANTINE net                                                            |
| Rule integrity                 | Both rules are IPv4 Block, protocol any, logging enabled, with approved destinations and descriptions |
| DNS isolation                  | No manual DNS pass rule exists on CYBER_QUARANTINE                                                    |
| Template integrity             | CYBER_ANALYSIS remains unchanged at twenty automatic plus three active interface rules                |
| Active-purpose integrity       | The other five active-purpose interfaces remain at twenty automatic plus three active rules each      |
| Pending state                  | The pending-change reminder is present; Apply is not selected                                         |
| Containment                    | No existing rule, alias, NAT, DNS/DHCP, IPv6, guest, service, WAN/LAN, or upstream change             |

| **Gate 7.3C-6 recorded result:** PASSED 3 September 2026. The submitted CYBER_QUARANTINE table showed the global pending-change reminder and twenty-two total entries: twenty automatic rules plus exactly two enabled manual IPv4 block rules. Both manual rules used CYBER_QUARANTINE network as Source, retained logging, and appeared in the approved order: Block OPNsense Control Plane to This Firewall followed by Block Private and Inter-Zone Networks to RFC1918_NETWORKS. No manual DNS pass rule was present. The submitted CYBER_ANALYSIS table remained unchanged at twenty automatic rules plus its three active interface rules in the approved order. The global pending reminder remained present, so the quarantine pair had not entered runtime. No existing rule or automatic rule was altered. |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

## 7.3C-7 Apply CYBER_QUARANTINE block-only pair and validate continuity

This checkpoint activates only the already-staged CYBER_QUARANTINE block-only pair. Because no guest is attached to the interface, immediate acceptance is limited to exact rule-table integrity, successful configuration activation, absence of a pending reminder, and uninterrupted access through both approved OPNsense management paths. Behavioral isolation testing remains a later gate.

56. From Kali01 at https://10.10.1.1, open Firewall \> Rules \> CYBER_QUARANTINE. Confirm the pending-change reminder is present and the table still shows twenty automatic rules plus exactly two enabled interface rules in this order: This Firewall block, then RFC1918_NETWORKS block. Confirm both use CYBER_QUARANTINE net as Source, logging is enabled, and no manual DNS pass exists. Do not edit any field.

57. Open CYBER_ANALYSIS. Confirm the global pending-change reminder is still present and the table remains at twenty automatic rules plus three active interface rules in the approved order. Do not edit a source rule.

58. Return to CYBER_QUARANTINE and select Apply exactly once. Wait for OPNsense to report successful application. Do not select Apply again, refresh during processing, navigate away, or make another configuration change.

59. After processing completes, refresh Firewall \> Rules \> CYBER_QUARANTINE. Confirm the pending-change reminder is absent and the table still shows twenty automatic rules plus the same two enabled block rules with their approved Sources, destinations, logging states, order, and descriptions.

60. Reopen CYBER_ANALYSIS and confirm the pending reminder is absent and its twenty automatic plus three active interface rules remain unchanged. Verify CYBER_ATTACK, CYBER_WINDOWS, CYBER_LINUX, CYBER_APPS, and CYBER_SIEM remain at twenty automatic plus three active interface rules each. Do not edit any table.

61. From Kali01, open https://10.10.1.1 in a new tab and confirm the primary OPNsense management path loads normally. Do not change LAN policy.

62. From Admin01, open https://192.168.10.120 and confirm the approved WAN emergency-management path still loads the OPNsense GUI. Do not change WAN policy.

63. Capture the post-Apply CYBER_QUARANTINE table, the unchanged CYBER_ANALYSIS table, and evidence of both successful management paths. Submit the evidence and stop. Do not attach a guest or begin the post-policy recovery export.

| **Gate 7.3C-7 pass condition** | **Required evidence**                                                                               |
|--------------------------------|-----------------------------------------------------------------------------------------------------|
| Activation                     | Apply completes exactly once with no reported error                                                 |
| Pending state                  | The pending-change reminder is absent after refresh                                                 |
| Quarantine count               | Twenty automatic rules plus exactly two enabled interface rules                                     |
| Quarantine integrity           | Logged IPv4 blocks remain in the approved order with CYBER_QUARANTINE net as Source                 |
| DNS isolation                  | No manual DNS pass rule exists on CYBER_QUARANTINE                                                  |
| Active-purpose integrity       | All six active-purpose tables remain at twenty automatic plus three active rules                    |
| Primary management             | Kali01 reaches the GUI at https://10.10.1.1                                                         |
| Emergency management           | Admin01 reaches the GUI at https://192.168.10.120                                                   |
| Containment                    | No rule edit, second Apply, alias, NAT, DNS/DHCP, IPv6, guest, service, WAN/LAN, or upstream change |

| **Gate 7.3C-7 recorded result:** PASSED 3 September 2026. Apply completed and the submitted post-Apply tables showed no pending-change reminder. CYBER_QUARANTINE remained at twenty-two total entries: twenty automatic rules plus exactly two enabled manual IPv4 block rules in the approved order, with CYBER_QUARANTINE network as Source, logging retained, and no manual DNS pass. CYBER_ANALYSIS remained unchanged at twenty automatic rules plus its three active interface rules in the approved order. The operator confirmed that the approved OPNsense management access remained available. No rule edit, second Apply, guest attachment, or other configuration change was made. |
|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

## 7.3C-8 Final post-policy recovery export and validation

This recovery-only checkpoint captures the current running configuration after all seven cyber interface policies have been activated and verified. It authorizes a fresh export and local integrity checks only. It does not authorize restoration, configuration-history changes, firewall edits, guest attachment, or behavioral traffic testing.

64. From Kali01 at https://10.10.1.1, confirm the OPNsense GUI still loads. From Admin01, confirm https://192.168.10.120 still loads. If either approved management path fails, stop before export.

65. From Kali01, open System \> Configuration \> Backups, or the equivalent configuration-backup page. Select only the current running configuration and download a fresh XML export. Do not restore, revert, edit, or select a historical configuration.

66. On Kali01, open a terminal and run the following block exactly. It selects the newest XML in Downloads, proves it is non-empty, records its SHA-256 digest, validates one OPNsense root element, and reports case-insensitive occurrence counts for the seven cyber interfaces and the approved policy identifiers.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>config_file="$(find "$HOME/Downloads" -maxdepth 1 -type f -name '*.xml' -printf '%T@ %p\n' | sort -nr | head -n 1 | cut -d' ' -f2-)"<br />
test -n "$config_file" &amp;&amp; test -s "$config_file"<br />
printf 'FILE=%s\n' "$config_file"<br />
stat --printf='SIZE=%s\n' "$config_file"<br />
sha256sum "$config_file"<br />
grep -c '&lt;opnsense' "$config_file"<br />
for item in CYBER_ATTACK CYBER_WINDOWS CYBER_LINUX CYBER_APPS CYBER_SIEM CYBER_ANALYSIS CYBER_QUARANTINE; do printf '%s=' "$item"; grep -ci "$item" "$config_file"; done<br />
for item in 'Allow DNS to OPNsense' 'Block OPNsense Control Plane' 'Block Private and Inter-Zone Networks' RFC1918_NETWORKS; do printf '%s=' "$item"; grep -ci "$item" "$config_file"; done</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

67. Confirm the terminal reports a file path, a positive byte size, a SHA-256 digest, exactly one OPNsense root occurrence, and a count of at least one for every listed cyber interface, each of the three policy descriptions, and RFC1918_NETWORKS. Confirm the filename is the newly downloaded export rather than the earlier Gate 7.3C-3 recovery file.

68. Capture the backup-page state and the complete terminal output showing filename, size, digest, root count, interface counts, and policy-identifier counts. Record the fresh XML filename and SHA-256 digest in the evidence package.

69. Submit the evidence and stop. Preserve the fresh XML as the post-policy recovery artifact. Do not attach a guest, begin behavioral testing, edit policy, or select Apply.

| **Gate 7.3C-8 pass condition** | **Required evidence**                                                            |
|--------------------------------|----------------------------------------------------------------------------------|
| Fresh export                   | A newly downloaded, non-empty current-configuration XML                          |
| Integrity record               | Filename, positive size, and SHA-256 digest are recorded                         |
| Root validation                | The \<opnsense search returns exactly 1                                          |
| Interface presence             | All seven cyber interface names return counts of at least 1                      |
| Policy presence                | All three descriptions and RFC1918_NETWORKS return counts of at least 1          |
| Primary management             | Kali01 reaches the GUI at https://10.10.1.1                                      |
| Emergency management           | Admin01 reaches the GUI at https://192.168.10.120                                |
| Containment                    | No restore, history change, firewall edit/Apply, guest, or infrastructure change |

| **Gate 7.3C-8 recorded result:** PASSED 3 September 2026. The operator confirmed management access remained available and downloaded a fresh current configuration export named config-OPNsense01.polaris.home.arpa-20260902222448.xml. The export was 120195 bytes with SHA-256 04cc6af667030210aaf96541824be616ac8230940fe0f7a2f73ae37c7c726dcf and exactly one \<opnsense root occurrence. Each of CYBER_ATTACK, CYBER_WINDOWS, CYBER_LINUX, CYBER_APPS, CYBER_SIEM, CYBER_ANALYSIS, and CYBER_QUARANTINE returned 2 occurrences; each of the three approved policy descriptions returned 7 occurrences; and RFC1918_NETWORKS returned 10. The fresh filename differed from the Gate 7.3C-3 export. No restore, history change, firewall edit/Apply, guest attachment, or other configuration change was made. |
|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

| **Post-runbook boundary:** RUN-002 is closed. Guest attachment, behavioral isolation testing, Internet or cross-zone exceptions, NAT changes, and scenario-specific policy require a separately approved and released execution checkpoint. |
|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

# Future gates - not yet released

| **Gate** | **Planned action**                                                           | **Release requirement**                                          |
|----------|------------------------------------------------------------------------------|------------------------------------------------------------------|
| 8        | Attach controlled test guests and run the positive/negative isolation matrix | Firewall policy complete; no vulnerable production-like payloads |
| 9        | Create post-change backups and publish as-built closeout                     | All tests pass; no bypass or unexpected reachability             |

# Minimum isolation matrix for future Gate 8

| **Source**          | **Destination**                                               | **Expected**                                            |
|---------------------|---------------------------------------------------------------|---------------------------------------------------------|
| Kali01 / management | OPNsense management                                           | Allow                                                   |
| Approved attack VM  | Selected target family                                        | Allow only scenario ports                               |
| Approved target     | Selected SIEM                                                 | Allow only required telemetry                           |
| Any vulnerable zone | Internet                                                      | Allow only where explicitly authorized through OPNsense |
| Any vulnerable zone | 192.168.10.0/24, 192.168.68.0/24, 192.168.1.0/24              | Block                                                   |
| Any vulnerable zone | NAS01, Proxmox, cluster services, CGNAT/Tailscale, link-local | Block                                                   |
| VLAN 99             | Any upstream or other zone                                    | Block                                                   |
| Any cyber guest     | IPv6 upstream                                                 | Block / unavailable                                     |
| OPNsense stopped    | Any cyber upstream                                            | Fail closed                                             |

# Revision history

| **Version** | **Date**    | **Summary**                                                                                                                                                                                                                                        |
|-------------|-------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1.0         | 21 Aug 2026 | Initial recovery-first runbook for approved cyberrange VLAN segmentation; Gates 1-5 authorized.                                                                                                                                                    |
| 1.1         | 21 Aug 2026 | Recorded Gate 2 pass and added the approved VLAN-aligned VMID allocation standard; Gate 3 released.                                                                                                                                                |
| 1.2         | 21 Aug 2026 | Recorded Gate 3 pass from XML, snapshot, archive, and scheduled-backup evidence; strengthened archive-content validation and released Gate 4.                                                                                                      |
| 1.3         | 21 Aug 2026 | Recorded verified Gate 4 host-archive/NAS copy and Gate 5 VLAN-aware bridge completion; released a bounded Gate 6 for OPNsense VLAN objects, assignments, and gateway addresses only.                                                              |
| 1.4         | 28 Aug 2026 | Recorded Gate 6 VLAN/interface, management, quorum, and matching XML evidence; released Gate 7.1 for a VM300 pre-policy snapshot and read-only service/policy baseline.                                                                            |
| 1.5         | 29 Aug 2026 | Recorded Gate 7.1A snapshot completion; established GUI-first execution as the standing operator rule; and released only the read-only Gate 7.1B-1 OPNsense GUI service-identity checkpoint.                                                       |
| 1.6         | 29 Aug 2026 | Recorded Gate 7.1B-1 management and service evidence; preserved the existing Dnsmasq-Unbound polaris.home.arpa forwarding path; and released only the GUI read-only Gate 7.1B-2A DNS/DHCP configuration inventory.                                 |
| 1.7         | 29 Aug 2026 | Recorded Gate 7.1B-2A DNS/DHCP evidence and the LAN pool overlap with Kali01; released only the GUI read-only Gate 7.1B-2B outbound NAT, alias, floating-rule, and per-interface firewall-rule inventory.                                          |
| 1.8         | 30 Aug 2026 | Recorded Gate 7.1B-2B automatic Source NAT, alias, floating-rule, WAN, LAN, and empty cyber-interface rule evidence; released only the final GUI-only Gate 7.1C continuity checkpoint.                                                             |
| 1.9         | 30 Aug 2026 | Recorded Gate 7.1C interface, service, upstream, DNS, client, emergency management, and recovery-artifact continuity evidence; released only Gate 7.2A to remove the Kali01 overlap from the LAN DHCP range.                                       |
| 1.10        | 31 Aug 2026 | Recorded the Gate 7.2A stop-condition response, corrected Kali01 from DHCP to its approved static address, applied the non-overlapping LAN pool, validated continuity, and held Gate 7.2B for explicit DHCP/DNS design approval.                   |
| 1.11        | 31 Aug 2026 | Recorded Gate 7.2B approval of zone-specific subdomains beneath cyberrange.home.arpa; preserved separation from polaris.home.arpa and ad.polaris; and released only Gate 7.2C for the bounded Dnsmasq interface and cyber-VLAN IPv4 range changes. |
| 1.12        | 1 Sep 2026  | Recorded Gate 7.2C Dnsmasq interface/range completion and continuity evidence; preserved the approved zone-specific namespace; and released only Gate 7.2D for fourteen bounded Unbound forward and reverse-zone entries to Dnsmasq.               |
| 1.13        | 1 Sep 2026  | Recorded Gate 7.2D Unbound forwarding and continuity completion; preserved the isolated cyberrange DNS design; and released only Gate 7.3A for a read-only post-DNS inventory of the LAN and seven CYBER firewall-rule tables.                     |
| 1.14        | 1 Sep 2026  | Recorded Gate 7.3A post-DNS rule inventory; confirmed identical automatic-only cyber interfaces and the preserved LAN policy; and released only Gate 7.3B for approval of the no-new-alias, per-interface, default-closed policy design.           |
| 1.15        | 1 Sep 2026  | Recorded approval of the Gate 7.3B no-new-alias, per-interface, default-closed policy design and released only Gate 7.3C-1 to build and inspect the pending three-rule CYBER_ANALYSIS template before Apply.                                       |
| 1.16        | 2 Sep 2026  | Recorded Gate 7.3C-1 pending-template completion and released only Gate 7.3C-2 to apply the CYBER_ANALYSIS rules once and validate both approved management paths.                                                                                 |
| 1.17        | 2 Sep 2026  | Recorded Gate 7.3C-2 application and management-continuity completion and released only Gate 7.3C-3 to export and validate a post-Apply recovery configuration.                                                                                    |
| 1.18        | 2 Sep 2026  | Recorded Gate 7.3C-3 recovery-export completion and released only Gate 7.3C-4 to clone, save, and inspect the pending three-rule template on five active-purpose interfaces without Apply.                                                         |
| 1.19        | 2 Sep 2026  | Recorded Gate 7.3C-4 pending-rule cloning and inspection completion and released only Gate 7.3C-5 to apply the staged five-interface changeset once and validate policy and management continuity.                                                 |
| 1.20        | 2 Sep 2026  | Recorded Gate 7.3C-5 five-interface activation and continuity completion and released only Gate 7.3C-6 to stage and inspect the pending CYBER_QUARANTINE block-only rule pair without Apply.                                                       |
| 1.21        | 3 Sep 2026  | Recorded Gate 7.3C-6 pending quarantine-rule staging and inspection completion and released only Gate 7.3C-7 to apply the verified CYBER_QUARANTINE block-only pair once and validate continuity.                                                  |
| 1.22        | 3 Sep 2026  | Recorded Gate 7.3C-7 quarantine-policy activation, table-integrity, and management-continuity completion and released only Gate 7.3C-8 for the final post-policy recovery export and validation.                                                   |
| 1.23        | 3 Sep 2026  | Recorded Gate 7.3C-8 final post-policy recovery-export validation and closed the Gate 7.3C execution sequence with no additional action released under RUN-002.                                                                                    |
