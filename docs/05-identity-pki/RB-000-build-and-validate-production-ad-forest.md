Runbook-001: Build and Validate a Production Active Directory Forest

#Purpose
Repeatable deployment and validation process.

#Prerequisites
Snapshots, backups, static IPs, synchronized time.

#IP Plan
DC01 192.168.10.40
ADMIN-WS 192.168.10.41
WS01 192.168.10.42
Gateway 192.168.10.1

#Deployment
Install AD DS/DNS, create forest ad.polaris, configure forwarders.

#Client Join
Static IP, DNS=192.168.10.40 only, join domain, reboot.

#Validation
dcdiag
repadmin /replsummary
nslookup dc01.ad.polaris
nslookup google.com
nltest /dsgetdc:ad.polaris
nltest /sc_verify:ad.polaris

#Acceptance
All validation commands pass; snapshots and backups completed.
