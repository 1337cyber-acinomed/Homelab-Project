# Project Polaris Troubleshooting Record

## TR-0001 – Proxmox Host Unreachable After WAN Bridge Migration

Summary

Following migration of the Proxmox management interface from the original WAN address to a new static address, the Proxmox host remained locally reachable but exhibited inconsistent behavior when sourced from the original IP address. Tailscale access, management connectivity, and remote browser access failed despite the Proxmox services remaining healthy.

The root cause was ultimately identified as Linux source address selection caused by multiple IP addresses being assigned to the bridge interface simultaneously.

Environment

Host:

Proxmox VE 9
Single-node deployment
vmbr0 connected to Intel I350 NIC (nic4)
Static management network

Original Management IP

192.168.68.56

New Management IP

192.168.68.70
Symptoms

Observed:

Browser unable to reach Proxmox UI
Tailscale unable to connect remotely
TCP connection timeout on port 8006
Ping failures from Proxmox shell when using default source address
curl to localhost successful
pveproxy active
pvedaemon active
Cluster healthy
Network adapter operational
Initial Hypotheses

The following possibilities were investigated.

1. NIC Driver Failure

Verified with

lspci -nnk

Result:

Intel I350 driver (igb) loaded correctly.

Ruled Out.

2. Hardware Offloading

Disabled:

GRO
GSO
TSO
LRO
RX/TX checksum offloading

Purpose:

Determine whether NIC checksum or segmentation offloading was corrupting packets.

Result:

No change.

Hardware offloading restored.

Ruled Out.

3. Reverse Path Filtering

Verified:

sysctl net.ipv4.conf.all.rp_filter
sysctl net.ipv4.conf.nic4.rp_filter

Result:

2

Loose mode already configured.

Ruled Out.

4. Bridge Learning

Verified:

bridge fdb show

MAC learning operating correctly.

Ruled Out.

5. ARP Resolution

Verified:

ip neigh

Gateway

192.168.68.1

was REACHABLE.

Ruled Out.

6. Routing

Verified:

ip route get 192.168.68.1

Result:

Correct route via vmbr0.

Ruled Out.

7. Packet Capture

Captured traffic with

tcpdump -eni nic4 icmp

Observed:

Outbound Echo Requests

Inbound Echo Replies

This proved:

switch forwarding correctly
gateway replying
packets physically arriving

This became the first major clue.

Discovery

Testing with

ping -I 192.168.68.70 192.168.68.1

worked immediately.

Likewise

ping -I 192.168.68.70 8.8.8.8

worked perfectly.

Whereas

ping 192.168.68.1

failed.

Critical Finding

Inspection of vmbr0 showed:

192.168.68.56
(primary)

192.168.68.70
(secondary)

Linux was automatically selecting the primary address (.56) as the source IP.

Replies destined for

192.168.68.70

were valid.

Replies destined for

192.168.68.56

no longer matched the intended management address after migration.

Although both addresses were configured, Linux continued preferring the original address.

Resolution

Removed the obsolete address.

Retained only

192.168.68.70

Confirmed

ip addr show vmbr0

returned only

192.168.68.70

Subsequent testing:

ping 192.168.68.1

Success.

ping 8.8.8.8

Success.

curl https://127.0.0.1:8006

Success.

Browser access restored.

Secondary Investigation – Remote Access

Remote access still failed.

Additional diagnostics confirmed:

Proxmox services healthy
Port 8006 listening
curl successful
Tailscale connected on Proxmox

Problem isolated to Windows client.

Root Cause

Windows laptop had Proton VPN enabled.

Although Tailscale executables and the Tailscale subnet had previously been configured for split tunneling, Proton VPN still interfered with Tailscale connectivity.

Disabling Proton VPN immediately restored:

Tailscale connectivity
Port 8006 access
Browser management

This established that the VPN issue was independent of the Proxmox networking issue.

Lessons Learned
Lesson 1

When changing a Linux management IP:

Always verify

ip addr show <interface>

contains only the intended management address.

Multiple addresses can lead to unexpected source IP selection.

Lesson 2

Packet capture is invaluable.

Seeing both ICMP requests and replies immediately ruled out:

switch failure
bridge failure
gateway failure
NIC failure

and narrowed the problem to host networking.

Lesson 3

ping -I <source> is an excellent diagnostic.

It rapidly distinguishes routing problems from source-address-selection problems.

Lesson 4

Validate locally before remotely.

Checking:

systemctl
ss
curl

proved Proxmox itself was healthy before investigating Tailscale.

Lesson 5

Treat concurrent failures as potentially unrelated.

The Proxmox IP migration issue and the Proton VPN/Tailscale interaction occurred at nearly the same time but had separate causes. Resolving one did not resolve the other.

Commands Used
lspci -nnk

ethtool -K

sysctl

ip neigh

bridge fdb show

ip route get

ip addr show

tcpdump -eni nic4 icmp

ping

ping -I

curl

systemctl status

ss -tln

tailscale status
