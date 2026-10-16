# pfSense REST API v2 — Endpoint/Privilege Survey for the Planned Networking Query Agent Tool List

**Context:** Step 7 gateway01/firewall01 replication, Part 1 equivalent. This is the pfSense-side counterpart to `claude/opnsense-diagnostics-acl-privilege-mapping.md` — same purpose (map the planned read-only tool list to real, narrow, verifiable privileges before building anything), different mechanism, since pfSense's REST API v2 package defines its own privilege system rather than reusing OPNsense's `ACL.xml`. Companion doc `claude/pfsense-rest-api-package-firmware-upgrade-sop.md` covers the firmware-upgrade/package-persistence and v1-vs-v2 questions; this doc picks up where that one's "still open" list left off.

**Status: first-pass source read against the package's current `main` (commit `d346137`, 2026-09-03, same as `v2.10.2`), done ahead of the actual gateway01/firewall01 upgrade — not yet verified against a real installed package on either box.** Per the standing principle already proven on cyber-fw01 (an upstream `HEAD` analysis didn't hold against the real deployed version), **this whole doc needs re-confirmation once gateway01/firewall01 are actually on 2.9.0 with the REST API package actually installed** — both because a newer package release may exist by then, and because nothing here has been tested against a live box yet (no empirical GET/403 tests the way the OPNsense doc eventually did).

## How this mechanism works (read directly from source, not inferred)

Confirmed in `pfSense-pkg-RESTAPI/files/usr/local/pkg/RESTAPI/Core/Endpoint.inc`:

- Every API endpoint class declares which HTTP methods it supports (`$request_method_options`, e.g. `['GET', 'DELETE']`).
- `generate_pfsense_privs()` auto-generates **one dedicated pfSense privilege per endpoint per supported HTTP method** — GET and DELETE on the same endpoint are two completely separate, independently-grantable privileges, not a bundle. This is a materially better starting position than OPNsense's model, where e.g. `page-status-interfaces` bundled the read (`interfaces_info`) and a write action (`reload_interface`) under one grant, forcing a "never wire a tool node to the write action" mitigation as the only safeguard.
- Privilege naming is mechanical and predictable: take the endpoint's URL, replace `/` and `_` with `-`, strip the leading `-`, append the lowercase HTTP method. E.g. `/api/v2/diagnostics/arp_table` + `GET` → `api-v2-diagnostics-arp-table-get`.
- **Only one endpoint in the entire package requires full admin (`page-all`) instead of a dedicated privilege**: `SystemRESTAPISettingsSyncEndpoint` (the REST API package's own HA-sync-settings endpoint) — confirmed by grepping every `Endpoints/*.inc` file for `requires_page_all_privilege = true`. Default for every other endpoint is `false` (confirmed in `Core/Endpoint.inc`). This is a dramatically smaller "permanently unreachable without full admin" set than OPNsense had (where `get_interface_config` had no narrower privilege and was ruled permanently out of scope) — and the one page-all endpoint here is irrelevant to this project's tool list anyway.

## Endpoint survey against the planned tool list (cyber-fw01's 10-tool shape, as a reference point — not a commitment to match it 1:1)

All URLs, methods, and the page-all check below are confirmed directly from each endpoint class's source, not guessed from naming:

| Planned tool (OPNsense equivalent) | pfSense REST API v2 endpoint | Methods | GET-only privilege | page-all required? |
|---|---|---|---|---|
| ARP table | `GET /api/v2/diagnostics/arp_table` | GET, DELETE | `api-v2-diagnostics-arp-table-get` | No |
| NDP table | **No equivalent endpoint exists.** Searched the full `Endpoints/` and `Models/` trees for "ndp"/"neighbor" — no matches. pfSense REST API v2 currently has no IPv6-neighbor-table endpoint. | — | — | — |
| Routing table (static routes) | `GET /api/v2/routing/static_routes` | GET, DELETE | `api-v2-routing-static-routes-get` | No |
| Gateway status (not in OPNsense list, but live gateway up/down/latency is arguably better than static config here) | `GET /api/v2/status/gateways` | GET only | `api-v2-status-gateways-get` | No |
| Interface status/IP | `GET /api/v2/status/interfaces` | **GET only** — no PATCH/POST/PUT/DELETE defined on this endpoint at all | `api-v2-status-interfaces-get` | No |
| Interface names/list (config) | `GET /api/v2/interfaces` | GET, DELETE | `api-v2-interfaces-get` | No |
| Firewall aliases (list/config) | `GET /api/v2/firewall/aliases` | GET, PUT, DELETE | `api-v2-firewall-aliases-get` | No |
| Alias contents (live PF table) | `GET /api/v2/diagnostics/table` (by alias name) | GET, DELETE | `api-v2-diagnostics-table-get` | No |
| Firewall rules | `GET /api/v2/firewall/rules` | GET, PUT, DELETE | `api-v2-firewall-rules-get` | No |
| Firewall states | `GET /api/v2/firewall/states` (+ singular `/state`) | GET, DELETE | `api-v2-firewall-states-get` | No |
| Firewall states count/size | `GET /api/v2/firewall/states/size` | GET, PATCH | `api-v2-firewall-states-size-get` | No |
| Firewall statistics (pf_statistics-equivalent: memory/timeouts/interface counters) | **Not yet found.** Searched filenames for "stat" and came up empty beyond states/status endpoints already listed above. Doesn't mean it doesn't exist — may be under a less obvious name, or may genuinely not be exposed by this API and only reachable via `pftop`/SSH. Needs a deeper, non-filename-based search (grepping endpoint `$url` values directly) before concluding either way. | — | — | — |
| Neighbor proxy config | **No pfSense equivalent concept found.** OPNsense's Neighbor Proxy is an OPNsense-specific virtual-interface feature; nothing suggests pfSense has the same feature, so this tool likely just doesn't carry over, not a gap to fill. Not fully verified either way yet. | — | — | — |
| Rule state (local SQLite baseline/drift lookup) | N/A — this was never a live API call on cyber-fw01 either (local-only tool reading Part 2's own DB). Carries over unchanged in concept once a pfSense-side Part 2 exists; not an API/privilege question. | — | — | — |

## The one finding worth flagging prominently: pfSense may not need OPNsense's "no live rule reads" compromise

On cyber-fw01, Part 1 was explicitly designed to **never** call a live rules API — the only JSON path to rule data (`page-filter-api`) had no read/write split at all, so granting it to the AI-reachable `polaris-networking-readonly` account would have hinded that account real rule-write capability. The workaround was routing rule questions through Part 2's own SQLite baseline instead.

**That constraint may not exist on pfSense.** `FirewallRulesEndpoint`'s GET privilege (`api-v2-firewall-rules-get`) is confirmed structurally separate from its PUT/DELETE privileges, with no `page-all` requirement. If that holds up under live testing, a pfSense-side Part 1 could plausibly read live firewall rules directly and safely, with zero mutation capability on that credential — a cleaner design than what cyber-fw01 had to settle for, not just a port of it. **This is a real design opportunity, not a decision** — needs the same "confirm, don't assume" live test cyber-fw01 got (grant only the GET privilege, confirm a write attempt 403s) before it's trusted, and is worth discussing explicitly rather than silently copying either cyber-fw01's workaround or this more permissive approach.

## Still open / not yet done

- **Re-verification against the actual installed version**, once gateway01/firewall01 are on 2.9.0 with the REST API package actually installed — this entire doc is pre-upgrade, source-only analysis so far, same caveat the OPNsense doc started with before its HEAD-vs-26.7.1 correction.
- **Firewall-statistics-equivalent endpoint** — not yet found, not yet confirmed absent. Needs a `$url`-value grep across the full `Endpoints/` tree rather than a filename search.
- **Live-rule-read design decision** (above) — needs to be explicitly discussed and decided, not defaulted either way.
- **The remaining ~230 endpoint classes in the package weren't reviewed** — this survey only pulled the ones matching cyber-fw01's existing 10-tool shape. Reasonable for a first pass, but the pfSense tool list doesn't have to be a 1:1 port of OPNsense's — worth a deliberate "what should this tool list actually be" pass once the above opens are closed, rather than assuming parity.
- Full credential-bootstrap (group/user/API-key/access-list scoping) — not started; the access_list-scoping note from the firmware-upgrade-SOP doc (scope to the orchestrator's IP, don't leave the default allow-all) still applies here as the eventual build step.

## Sources

- `pfrest/pfSense-pkg-RESTAPI` source, read directly (shallow clone, `main` @ `d346137`, 2026-09-03 — same commit as tag `v2.10.2`): `Core/Endpoint.inc` (privilege-generation mechanism, naming function, default/`page-all` logic), and the individual `Endpoints/*.inc` files named in the table above (`$url`, `$request_method_options`).
