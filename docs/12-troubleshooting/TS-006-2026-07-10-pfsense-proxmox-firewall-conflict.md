Incident summary

Firewall01 lost WAN connectivity. LAN clients could communicate with the pfSense LAN interface but could not reach the Internet. During troubleshooting, Firewall01 was shut down and then failed to restart because its virtual disk referenced a nonexistent Proxmox storage ID.

Affected systems
Firewall01 — VMID 101
ADMIN-WS — VMID 201
Other systems using Firewall01 as their default gateway
Initial symptoms
ADMIN-WS reported no Internet connection.
ADMIN-WS could ping 192.168.10.1.
ADMIN-WS could not ping 8.8.8.8.
DNS and direct Internet tests failed.
Firewall01 could not ping 192.168.68.1.
Firewall01 could not ping 8.8.8.8.
WAN gateway monitoring showed 100% packet loss.
The Deco interface did not list Firewall01 as a connected client.
Verified client configuration

ADMIN-WS was correctly configured:

IPv4 address:  192.168.10.41
Subnet mask:   255.255.255.0
Default gateway: 192.168.10.1
DNS server:    192.168.10.40
DNS suffix:    polaris.home.arpa

Because ADMIN-WS could reach the pfSense LAN interface but not an external IP address, the fault was isolated upstream of the Windows client.

Proxmox network validation

The active firewall was confirmed as VMID 101.

Firewall01 interface mapping:

net0 / vtnet0 → vmbr0 → WAN
net1 / vtnet1 → vmbr2 → LAN
net2 / vtnet2 → vmbr1 → OPT1

The following were confirmed:

nic4 was UP and LOWER_UP.
vmbr0 was operational.
tap101i0 existed and was attached through the Proxmox firewall bridge path.
QEMU reported the expected virtual NIC mappings.
The Proxmox host could reach 192.168.68.1 and the Internet.

This ruled out a failed physical uplink or complete vmbr0 failure.

pfSense routing findings

The pfSense routing table contained no IPv4 default route.

The WAN interface was link-active but had no IPv4 address:

vtnet0:
    status: active
    inet6: link-local only
    no IPv4 address

The routing table lacked:

default → 192.168.68.1
192.168.68.0/22 → vtnet0

The command:

route -n get default

reported that no default route existed.

This explained:

No route to host
Failed gateway monitoring
Failed Internet access
Absence of an ARP entry for 192.168.68.1
DHCP findings

The pfSense configuration correctly specified DHCP on vtnet0:

<wan>
    <if>vtnet0</if>
    <ipaddr>dhcp</ipaddr>
</wan>

A foreground DHCP attempt showed:

DHCPDISCOVER
No DHCPOFFERS received

Therefore, pfSense was attempting to obtain an address, but no usable lease was being completed.

Proxmox firewall adjustment

All three Firewall01 NIC definitions initially contained:

firewall=1

The Proxmox firewall flags were removed from:

WAN
LAN
OPT1

This simplified Firewall01’s forwarding path and avoided placing an additional host firewall layer immediately around the pfSense appliance.

Secondary fault: invalid storage reference

After Firewall01 was shut down, Proxmox refused to restart it:

TASK ERROR: storage 'Firewall' does not exist

The VM configuration contained:

scsi0: Firewall:vm-101-disk-0

However, /etc/pve/storage.cfg defined:

Proxmox storage ID: VM
Underlying ZFS pool: Firewall

The VM had continued running because QEMU already had the disk open. Once stopped, Proxmox revalidated the configuration and rejected the nonexistent storage ID.

The disk reference was corrected to:

scsi0: VM:vm-101-disk-0

No disk was moved, copied, deleted, or reformatted. Only the Proxmox storage identifier in the VM configuration was corrected.

Final validation

After Firewall01 restarted:

WAN IPv4:     192.168.68.60
WAN network:  192.168.68.0/22
Default route: 192.168.68.1 via vtnet0

Validation succeeded:

Firewall01 could ping 192.168.68.1.
Firewall01 could ping external IP addresses.
ADMIN-WS could ping 8.8.8.8.
ADMIN-WS could resolve public DNS names.
ADMIN-WS could connect to TCP port 443 on Internet hosts.
Normal Internet access was restored.
Root-cause assessment

Two distinct faults were identified:

WAN connectivity failure: Firewall01 had no active IPv4 DHCP lease or default route. Connectivity returned after Firewall01 was restarted with the Proxmox NIC firewall flags removed.
Restart failure: The VM disk referenced Firewall, which was the ZFS pool name rather than the valid Proxmox storage ID VM.

The storage-reference failure is conclusively established. The exact individual trigger for the lost DHCP lease was not isolated between the prior Proxmox firewall path and stale runtime/DHCP state because both were cleared during the same controlled restart.

Permanent corrective actions
Firewall01 disk:
scsi0: VM:vm-101-disk-0,...

Firewall01 NICs:
Do not enable Proxmox NIC firewall filtering unless a deliberate,
documented layered-firewall design is implemented.
