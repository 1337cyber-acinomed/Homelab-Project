# pfSense REST API Package & Firmware-Upgrade SOP (gateway01/firewall01 pre-build)

**Context:** Step 7 gateway01/firewall01 replication (the pfSense equivalent of cyber-fw01's 7a). Both boxes are now fully bootstrapped (package installed, Access List scoped and enforcing, Key auth proven live via `X-API-Key`) — see the two bootstrap sections below. This doc answers the questions that blocked writing that bootstrap correctly: whether a pfSense firmware upgrade preserves or removes a third-party-installed package (it removes it, unconditionally), which REST API package generation to standardize on (v2, `pfSense-pkg-RESTAPI`), what actually does and doesn't survive that removal, the real confirmed state of both target boxes, and the actual network topology and NAT behavior between them, which determines what source IP each box's Access List needs to trust. This doc is the pfSense-specific counterpart to `claude/opnsense-diagnostics-acl-privilege-mapping.md` — not a replacement for it. Companion doc `claude/pfsense-restapi-privilege-mapping.md` picks up from here for the tool-list/privilege design, now that both boxes have working credentials to verify against.

## Confirmed device state, 2026-10-04

| Box | Hostname (per Dashboard) | Version (pre-upgrade) | Version (post-upgrade) |
|---|---|---|---|
| firewall01 | `pfsense.homelab.local` | 2.8.1-RELEASE | **2.9.0-RELEASE — confirmed, "system is on the latest version"** |
| gateway01 | `gateway01.home.arpa` | 2.8.1-RELEASE | **2.9.0-RELEASE — confirmed, "system is on the latest version"** |

**Both boxes upgraded and confirmed on 2.9.0-RELEASE as of 2026-10-04 14:51 PT.**

**Correction to an earlier version of this doc:** the "Mgmt IP" values originally recorded here (`192.168.10.30` for firewall01, `192.168.30.101` for gateway01) were wrong — those were read from the Dashboard's "User" field, which in pfSense shows `admin@<the browser's own source IP at the time of login>`, not the box's own address. Replaced below with each box's actual interface addresses, confirmed directly.

### Real topology, confirmed 2026-10-04

User-stated routing chain: **internet → gateway01 → firewall01 → homelab/AI nodes (CT402 sits here) → cyber-fw01 → cyberrange node.**

firewall01's actual interfaces (Status → Dashboard → Interfaces widget, re-confirmed independently via the live REST API test below):

| Interface | IP | Faces |
|---|---|---|
| WAN | `192.168.30.101` | gateway01 (upstream) |
| LAN | `192.168.10.1` | CT402/homelab (downstream) — same segment CT402 itself is on |
| CYBERMGMT (opt1) | `192.168.20.1` | cyber-fw01's management path |

gateway01's interfaces, now independently confirmed via its own live REST API test (`GET /api/v2/status/interfaces`, 2026-10-04):

| Interface | IP | Gateway | Faces |
|---|---|---|---|
| WAN | `192.168.1.125` | `192.168.1.1` | real upstream internet/modem |
| LAN | `192.168.30.1` | — | firewall01's WAN (`192.168.30.101`), same segment |

This confirms the earlier topology inference (gateway01's LAN-facing-firewall01 address is `192.168.30.1`) directly from the device itself, not just from ping/routing behavior.

**Outbound NAT, confirmed on firewall01 (Firewall → NAT → Outbound):** Mode = **Hybrid Outbound NAT** (automatic rules + manual rules below). The automatic ruleset includes a WAN-bound rule covering source `192.168.10.0/24` (LAN) and `192.168.20.0/24` (CYBERMGMT), any destination, NAT'd to **WAN address** (`192.168.30.101`). This means: **any traffic from CT402 (`192.168.10.201`) that crosses firewall01 toward gateway01 arrives at gateway01 with a source IP of `192.168.30.101` (firewall01's WAN address), not CT402's real IP.** CT402's real address is only visible as-is to boxes on its own direct LAN segment (firewall01, cyber-fw01) — anything one hop further upstream through firewall01's WAN sees firewall01 itself as the source, due to NAT.

### Resolved: the two Access List entries this topology actually requires

| Box | Access List network | Why |
|---|---|---|
| **firewall01** | `192.168.10.201/32` (CT402's real IP) | CT402 is directly on firewall01's LAN segment — no NAT hop, same precision as cyber-fw01's existing orchestrator rule. |
| **gateway01** | `192.168.30.101/32` (firewall01's WAN address) | CT402's traffic is NAT'd to this address by the time it reaches gateway01 — this is the only source IP gateway01 can actually distinguish. Scoping to CT402's real IP here would never match and would silently block everything. |

**Honest limitation, worth stating plainly rather than glossing over:** gateway01's Access List, scoped this way, effectively trusts "anything routed from firewall01's LAN/CYBERMGMT side," not CT402 specifically — a real, structural precision loss compared to cyber-fw01's and firewall01's own rules, caused by the NAT hop, not a choice. No tighter source-IP scoping is achievable on gateway01's side without changing the NAT design (e.g. a dedicated outbound NAT rule for just CT402's IP, preserving a distinguishing address) — not proposed here, just named as the reason this one credential is slightly less tightly scoped than the project's others.

### How the Access List is actually enforced — confirmed from source, not assumed

Read `RESTAPIAccessListEntry::is_allowed_by_acl()` directly (`Models/RESTAPIAccessListEntry.inc`):

```php
foreach (RESTAPIAccessListEntry::read_all()->model_objects as $acl) {
    if ($acl->is_ip_match($ip) and $acl->is_user_match($username) and $acl->is_schedule_active()) {
        return $acl->type->value === 'allow';
    }
}
# Implicitly deny access if no ACL entry matches
return false;
```

**First-match-wins, top-down, implicit deny at the end** — same model as pf firewall rules themselves. This means: removing the two shipped "Default allow all IPv4/IPv6" entries and adding a single scoped `allow` entry is sufficient on its own — no explicit catch-all `deny` rule is needed underneath it, anything that doesn't match the one allow entry is already denied by default. Confirmed from the enforcement code (`Core/Endpoint.inc`'s `check_acl()`, which throws a `ForbiddenError` whenever this returns false), not inferred from the Settings page alone.

### How "Key" authentication is actually sent — confirmed from source/docs, not assumed (correction, 2026-10-04)

**The package's three Authentication Methods are genuinely different mechanisms, not three names for the same Basic Auth flow:**

| Method | How credentials are sent |
|---|---|
| **Local Database** | Standard HTTP Basic Auth (`Authorization: Basic ...`) — username + the account's real webConfigurator password. |
| **JWT** | Basic Auth once against `/api/v2/auth/jwt` to obtain a token, then `Authorization: Bearer <token>` on subsequent calls. Expires (default 3600s per the Settings page). |
| **Key** | A dedicated `X-API-Key: <key>` header — **not** Basic Auth, no username sent at all. The key alone is tied to the account that generated it. |

This project's own earlier instructions mischaracterized Key auth as "BasicAuth with the key as the password," which is wrong and caused a real failed first attempt during gateway01's bootstrap (see Gotchas below). Confirmed correct from [pfrest.org's Authentication & Authorization guide](https://pfrest.org/AUTHENTICATION_AND_AUTHORIZATION/), and now empirically proven on both boxes using the correct `X-API-Key` header.

**Correct Key-auth curl pattern, standardized for both boxes:**
```bash
curl -s -H "X-API-Key: <key>" 'https://<host>/api/v2/status/interfaces' -k
```

## Decision made, 2026-10-04: upgrade gateway01 and firewall01 to 2.9.0 before building

User's call, mirroring the cyber-fw01 precedent exactly: upgrade first, then build fresh against the new version. Deciding factor: 2.9.0's 20+ CVE security fixes, not REST API compatibility (both 2.8.1 and 2.9.0 are supported). **Done.**

## REST API package install mechanics (both boxes, 2026-10-04)

```bash
pkg-static add https://github.com/pfrest/pfSense-pkg-RESTAPI/releases/latest/download/pfSense-2.9.0-pkg-RESTAPI.pkg
```

Clean install confirmed on both boxes from terminal output: `pfSense-pkg-RESTAPI-2.10.2` (firewall01) / `-2.10_2` (gateway01, same release) fetched/extracted, endpoints/privileges/forms/schemas built, webConfigurator restart completed, no errors. New **System → REST API** menu present and functional (Settings/Keys/Access List/Updates/Documentation tabs) on both.

**Anomaly found and explained: System → Package Manager → Installed Packages shows "There are no packages currently installed," despite the package being genuinely installed and functional.** Confirmed from pfSense's own core source (`pfsense/pfsense` repo, `src/usr/local/www/pkg_mgr_installed.php` → `get_pkg_info()` in `src/etc/inc/pkg-utils.inc`):

```php
if (is_pkg_installed($pkg_info['name'])) {
    $rc = pkg_exec("query %R {$pkg_info['name']}", $out, $err);
    if (!$base_packages && rtrim($out) != g_get('product_name')) {
        continue;   // silently dropped from the Installed Packages list
    }
```

The page filters to only packages whose recorded origin repo (`pkg query %R`) equals pfSense's own official repo name. A package installed via bare `pkg-static add <url>` has no such repo tag and is silently skipped — cosmetic, specific to this one GUI page, further corroboration of Finding 1 rather than an install problem.

## Finding 1: pfSense firmware upgrades remove any package not from the official repo — confirmed from the package's own documentation

> "When updating pfSense, **you must reinstall this package afterward** as pfSense removes unofficial packages during system updates and has no way to automatically reinstall them."
> — [`docs/INSTALL_AND_CONFIG.md`](https://github.com/pfrest/pfSense-pkg-RESTAPI/blob/main/docs/INSTALL_AND_CONFIG.md), pfrest/pfSense-pkg-RESTAPI

Matters for every *future* upgrade of either box, not the one just completed.

### Supported pfSense versions (current package release)

pfSense CE 2.8.1, 2.9.0; pfSense Plus 25.11.1, 26.03, 26.03.1, 26.07.

## Finding 2: what actually survives a future removal, and what doesn't

- **Live settings (API keys, access list, auth method) are stored in pfSense's own main `config.xml`** (`installedpackages/package` stanza), which survives firmware upgrades. **Working conclusion, still not empirically proven** — no upgrade cycle has happened since install; confirm the first time either box goes through one with the package already configured.
- **"Keep Backup" does not help for firmware upgrades** — it writes to `/usr/local/share/pfSense-pkg-RESTAPI/backup.json`, inside the package's own tree, which is deleted along with the package. It covers package-version updates/reverts only.

## firewall01 bootstrap: ✅ complete, 2026-10-04

Access List and Key auth proven together, end to end, from CT402 against a real endpoint:

1. **Access List configured.** The two default "Default allow all IPv4/IPv6" entries removed; one scoped entry added — type `allow`, network `192.168.10.201/32`, description "orchestrator-n8n (CT402), direct LAN segment, no NAT." No catch-all `deny` rule needed underneath (implicit-deny behavior, confirmed from source above).
2. **Auth method: Key**, generated via the Keys tab, sent as an `X-API-Key` header (see the Key-auth correction above — not Basic Auth). No reason surfaced to deviate from this method.
3. **Live positive test from CT402 against `GET /api/v2/status/interfaces`: success.** `"code":200, "status":"ok", "response_id":"SUCCESS"`, with real interface data returned for all three interfaces — this also independently cross-confirmed the interface IPs already recorded in the topology table above (WAN `192.168.30.101`/gateway `192.168.30.1`, LAN `192.168.10.1`, CYBERMGMT `192.168.20.1`), since the API's own response matched the Dashboard/ping-derived values exactly.

firewall01 is fully bootstrapped: package installed, Access List scoped and enforcing, Key auth proven live via `X-API-Key`.

## gateway01 bootstrap: ✅ complete, 2026-10-04

1. **Package installed** (`pfSense-pkg-RESTAPI-2.10_2`), confirmed present in the GUI.
2. **Access List configured** — one scoped entry, type `allow`, network `192.168.30.101/32`, description "firewall01 WAN (NAT'd CT402 traffic)."
3. **API key generated** via the Keys tab, then **rotated** after the key value was briefly visible in a troubleshooting screenshot — standard hygiene, unrelated to any actual compromise.
4. **One false start, root-caused and fixed.** First attempt used `curl -u 'admin:<key>'` (HTTP Basic Auth) — the wrong mechanism for Key auth (see correction above). It was actually attempted as a Local Database login with the API key string as the password, failed with `401 AUTH_AUTHENTICATION_FAILED`, and was logged twice by `sshguard` as an "attack" (danger score 10) from `192.168.30.101`. Confirmed from `Status → System Logs → System`: `webConfigurator authentication error for user 'unknown' from: 192.168.30.101`, consistent with a Basic-Auth-against-Local-Database failure, not a Key-specific rejection. **The key itself was never actually invalid** — only the auth mechanism used to send it was wrong.
5. **Live positive test, corrected and confirmed: success.** `curl -s -H "X-API-Key: <rotated_key>" 'https://192.168.30.1/api/v2/status/interfaces' -k` → `"code":200, "status":"ok", "response_id":"SUCCESS"`, real interface data for both of gateway01's interfaces (WAN `192.168.1.125`/gateway `192.168.1.1`; LAN `192.168.30.1`) — see the topology table above, now independently confirmed from gateway01's own API rather than inferred.

gateway01 is fully bootstrapped: package installed, Access List scoped and enforcing, Key auth proven live via `X-API-Key`, using a rotated (never-exposed-live) credential.

**Gotcha, 2026-10-04, carried forward for any future credential bootstrap on this project: verify an auth mechanism's actual wire format from the package's own documentation before writing it into an SOP, not from naming/assumption.** This project's own earlier description of Key auth as "BasicAuth with the key as password" was wrong and caused a real failed-and-logged attempt. Confirmed correct from [pfrest.org's Authentication & Authorization guide](https://pfrest.org/AUTHENTICATION_AND_AUTHORIZATION/): Key auth is a dedicated `X-API-Key` header, structurally distinct from both Local Database (Basic Auth) and JWT (Bearer token). Same "confirm, don't assume" discipline already standing for ACL/privilege analysis — this extends it to auth-mechanism documentation specifically.

## Both boxes bootstrapped — status and next phase

**firewall01 and gateway01 are both fully bootstrapped as of 2026-10-04:** REST API package installed, Access List scoped to the correct NAT-aware source IP, Key auth proven live via the correct `X-API-Key` header, on 2.9.0-RELEASE with the current package release (`2.10.2`/`2.10_2`). This closes out the credential-bootstrap phase this doc exists to cover.

**Next phase (not started, tracked in `claude/pfsense-restapi-privilege-mapping.md`):** that doc's endpoint/privilege survey was done pre-upgrade, source-only, against the package's `main` branch — it now needs the same live re-verification cyber-fw01's OPNsense analysis got (confirm each planned tool's GET-only privilege actually works and a write attempt actually 403s), now that both boxes have real, working credentials to test against. That doc also has two open design questions worth deciding explicitly before building tool nodes: a missing NDP/firewall-statistics equivalent endpoint (not yet confirmed absent), and whether pfSense's cleaner GET/PUT/DELETE privilege separation means live firewall-rule reads are safe here even though cyber-fw01 had to avoid them.

## Sources

- [pfrest/pfSense-pkg-RESTAPI — `docs/INSTALL_AND_CONFIG.md`](https://github.com/pfrest/pfSense-pkg-RESTAPI/blob/main/docs/INSTALL_AND_CONFIG.md)
- [pfrest.org — Authentication & Authorization guide](https://pfrest.org/AUTHENTICATION_AND_AUTHORIZATION/) — authoritative source for the Key-auth `X-API-Key` header correction above, 2026-10-04
- pfrest/pfSense-pkg-RESTAPI source, read directly (shallow clone, `main` @ `d346137`, 2026-09-03): `RESTAPISettings.inc`, `manage.php`, `info.xml`, `Models/RESTAPIAccessListEntry.inc`, `Core/Endpoint.inc` — config-persistence, backup-file-location, and ACL-enforcement findings
- pfsense/pfsense source, read directly (shallow, sparse clone): `src/usr/local/www/pkg_mgr_installed.php`, `src/etc/inc/pkg-utils.inc` — Installed Packages repo-origin filtering
- [pfSense CE 2.9.0 release notes](https://docs.netgate.com/pfsense/en/latest/releases/2-9-0.html)
- [pfSense package handling policy change at 2.4.4](https://community.adamnet.works/hc/en-us/articles/360008102034)
- [pfrest/pfSense-pkg-RESTAPI discussion #500](https://github.com/pfrest/pfSense-pkg-RESTAPI/discussions/500)
- Live topology/NAT confirmation: user-provided screenshots (firewall01 Interfaces widget, Outbound NAT mappings, CT402 console `ping` test) and user's stated routing chain, 2026-10-04
- Live Access List + key auth proof on firewall01: user-provided terminal output, `GET /api/v2/status/interfaces` response, 2026-10-04
- gateway01 failed-auth diagnosis and corrected retest: user-provided screenshots (Settings, Keys, Access List tabs; `Status → System Logs → System` entries; final successful terminal output), 2026-10-04
