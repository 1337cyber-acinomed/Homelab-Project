# Static IP configuration troubleshooting

Title: TrueNas Static IP Configuration Did no Immediately Apply

Date: 2026-07-03

Service: storage01 (TrueNAS)

Secerity: low

## Problem
After changing the network interface from DHCP to a static Ip address, the TrueNAS web interface remained accesssible only through the previous DHCP
address instead of the newly configued static address.
------------------------------------------------------------------------------------------------------------------------------------------------------
## Symptoms
-Web GUI accessible at:
  192.168.10.106 (old IP)
-Web GUI inaccessible t 192.168.10.4 (new IP)
-midctl call interface.query reported the static configuration correctly
-ip addr show only displayed the DHCP address.
-ip route continued using the DHCP address as the source IP
------------------------------------------------------------------------------------------------------------------------------------------------------
## Root Cause
The TrueNAS configuration database successfully stored the new static network configuration, but the running Linux network stack continued using the
previously assigned DHCP lease. The configuration had not yet been applied to the active interface
------------------------------------------------------------------------------------------------------------------------------------------------------
## diagnostic steps
Verified current interface configuration
 ip addr show

Verified routing table
 ip route

Verified gateway connectivity
 ping -c 4 192.168.10.1

Verified stored configuration
midctl call interface.query
------------------------------------------------------------------------------------------------------------------------------------------------------
## Resolution
1. edited interface ens18
2. Disabled DHCP
3. Configured:
    static IP: 192.168.0.4/24
    Gateway: 192.168.10.1
4. Updated Global Configuration:
    Hostname
    Domain
    DNS
5. Rebooted the TrueNAS VM
6. Verified:
    ipaddr show now showed 192.168.0.4/24
7. Verified web inteface available at:
    http://192.168.10.4
-----------------------------------------------------------------------------------------------------------------------------------------------------
Verification:
-static IP active
-DHCP address removed
-Gateway reachable
-Web GUi accessible
-Uptime Kuma updated successfully
-----------------------------------------------------------------------------------------------------------------------------------------------------
## Prevention
After converting a TrueNAS interface from DHCP to a static IP, always verify both the stored configuration (midclt call interface.query) and the running
configuration (ip addr show). If they differ, perform a controlled reboot before making manual network changes
