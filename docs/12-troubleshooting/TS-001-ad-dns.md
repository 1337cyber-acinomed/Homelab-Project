1. Objective
Promote the first domain controller for polaris.home.arpa.
Validate Active Directory and DNS integration.
2. Initial Symptoms
dcdiag /q reported connectivity failures.
nslookup dc01 returned Non-existent domain.
Forward Lookup Zones initially appeared empty.
LDAP/RPC connectivity tests failed.
DNS records were incomplete or not registering.
3. Diagnostic Process
Verified DNS service was running.
Confirmed AD DS promotion completed successfully.
Checked Get-DnsServerZone to verify zones existed despite the MMC display confusion.
Enumerated DNS records with Get-DnsServerResourceRecord.
Verified _msdcs, DomainDnsZones, and ForestDnsZones partitions.
Confirmed GUID CNAME registration.
Validated DNS listener on TCP/UDP 53.
Checked Netlogon service.
Forced DNS registration (ipconfig /registerdns and nltest /dsregdns).
Restarted Netlogon.
Re-ran dcdiag.
4. Root Cause

The promotion succeeded, but DNS registrations had not fully completed immediately after promotion. Until Netlogon re-registered the required records, dcdiag interpreted the missing LDAP/RPC records as connectivity failures.

5. Resolution
Flushed DNS cache.
Registered DNS records.
Restarted Netlogon.
Forced domain registration.
Verified A, CNAME, SRV, and GUID records.
Confirmed successful dcdiag /test:dns /v.
6. Lessons Learned
Always validate with PowerShell (Get-DnsServerZone, Get-DnsServerResourceRecord) rather than relying solely on the DNS MMC.
Allow time for Netlogon and AD-integrated DNS to populate records after promotion.
Use dcdiag /test:dns /v as the definitive health check.
IPv6 root hint warnings are expected in an IPv4-only lab and can be safely documented rather than chased.
