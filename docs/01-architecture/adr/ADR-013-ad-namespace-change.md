ADR-0013: Active Directory Namespace and DNS Architecture

#Status
Accepted

#Context
Initial deployment used polaris.home.arpa with pfSense/Unbound forwarding the AD namespace, resulting in unreliable AD SRV resolution.
Decision
- Forest renamed to ad.polaris
- AD-integrated DNS is authoritative
- Domain clients use DC01 (192.168.10.40) as their only DNS server
- DC01 forwards Internet DNS to pfSense

#Rationale
Align with Microsoft enterprise best practices, simplify operations, and reduce technical debt.

#Consequences
Future domain members must point only to AD DNS.
