# ct404 internet egress toggle

> Source: `Claude Files/opening and closing internet on CT404.txt` (raw text preserved verbatim below)

```text
opening and closing internet on CT404

#open
iptables -P OUTPUT ACCEPT

#close
/root/bin/ct404-firewall-apply.sh

#persist close
systemctl stop ct404-fw-revert.timer
```
