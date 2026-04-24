# nixos-nftfw — Design

**Date:** 2026-04-24
**Status:** Draft — pre-implementation
**Owner:** Peter Horváth

## 1. Overview

`nixos-nftfw` is a NixOS module that generates `nftables` firewall configuration. It aims for **full coverage of the nftables feature surface** while remaining ergonomic for single-host, fleet, and edge-router deployments.

The module is built in two layers over two existing Nix libraries:

- **nix-libnet** — pure-Nix networking primitives (IPv4/IPv6 addresses, CIDR, ports, endpoints, listeners, MAC) with opt-in NixOS module option types. Used for input validation.
- **nix-nftypes** — complete typed Nix representation of the nftables libnftables-JSON schema (nftables 1.1.6), plus a high-level DSL and both text and JSON renderers. Used as the target data model.

The two layers are:

- **Layer A — nftables primitives.** A thin NixOS-options surface over nix-nftypes: tables, chains, sets, maps, and named stateful objects. Lives under `networking.nftfw.objects.*`. Accepts raw nftypes values via coercion for full escape when needed.
- **Layer B — firewall semantics.** Zones, nodes, and kind-typed rules that compile to Layer A primitives. Lives at the top of `networking.nftfw.*` (zones, nodes, rules). This is where users normally write.

Both layers emit text via nix-nftypes' `toText` into NixOS's native `networking.nftables.tables.<name>.content`, which drives activation through the standard `nftables.service`. No custom systemd unit.

## 2. Goals and non-goals

### Goals

1. **Full feature coverage.** Anything expressible in nftables 1.1.6 (and in nix-nftypes) is expressible here, either via Layer B sugar or Layer A escape.
2. **Ergonomic A/B/C deployments.**
   - **A** single-host — `enable = true;` plus a handful of rules yields a working firewall with no table/chain declarations.
   - **B** fleets — NixOS's ordinary module imports, conditionals, and overrides handle per-host specialization. No custom fragment/template system.
   - **C** edges/routers — zones with hierarchy, multi-family tables, named objects cross-table reuse, and NAT first-class.
3. **Composability via the NixOS module system.** Every piece of user-facing state is a NixOS option. Sharing rule fragments, overriding per host, and conditional inclusion all use standard `imports`, `mkDefault`, `mkIf`, and `mkForce`. No module-specific template or fragment system.
4. **General zone/node primitives.** Zones are hierarchical and defined by interfaces OR per-family addresses OR a raw expression override. Nodes belong to zones and are usable wherever a zone is.
5. **Extensibility.** New rule kinds, new helpers, and cross-cutting behavior plug into the compilation pipeline through documented extension points.
6. **Safe activation.** Pre-check via `nft -c`, stop-ruleset for remote-access safety, atomic kernel transitions through the native service.

### Non-goals

- Reinventing the nftables DSL. `nix-nftypes` already provides it.
- Runtime rule management. Configuration is fully static per NixOS generation.
- iptables compatibility.
- Docker/Kubernetes/Tailscale interoperability beyond cooperative-mode coexistence. Users running those decide their own base-chain compositions.

## 3. Top-level option surface

```
networking.nftfw
│
├── enable          : bool
├── authoritative   : bool = true
│
│   # Firewall semantics
├── zones           : attrsOf zoneSubmodule
├── nodes           : attrsOf nodeSubmodule
├── rules : {
│     filter   : attrsOf filterRuleSubmodule
│     icmp     : attrsOf icmpRuleSubmodule
│     mangle   : attrsOf mangleRuleSubmodule
│     dnat     : attrsOf dnatRuleSubmodule
│     snat     : attrsOf snatRuleSubmodule
│     redirect : attrsOf redirectRuleSubmodule
│     # extensible via sub-modules
│   }
│
│   # nftables primitives
├── objects : {
│     tables          : attrsOf tableSubmodule
│     chains          : attrsOf chainSubmodule
│     sets            : attrsOf setSubmodule
│     maps            : attrsOf mapSubmodule
│     counters        : attrsOf counterSubmodule
│     quotas          : attrsOf quotaSubmodule
│     limits          : attrsOf limitSubmodule
│     ct : {
│       helpers       : attrsOf ctHelperSubmodule
│       timeouts      : attrsOf ctTimeoutSubmodule
│       expectations  : attrsOf ctExpectationSubmodule
│     }
│     flowtables      : attrsOf flowtableSubmodule
│     secmarks        : attrsOf secmarkSubmodule
│     synproxies      : attrsOf synproxySubmodule
│     tunnels         : attrsOf tunnelSubmodule
│     ruleset         : nullOr nftypesRulesetType
│   }
│
├── helpers : {
│     stopRuleset          : { enable, keepAlivePorts, ... }
│     kernelHardening      : { enable, ... }
│     flowOffload          : { enable, zones, interfaces, hardware }
│     rpfilter             : { enable, strict, exemptInterfaces }
│     conntrackBaseline    : { enable }
│     loopbackAccept       : { enable }
│     ipForwarding         : { enable, ipv4, ipv6 }
│     defaults             : { enable }
│   }
│
└── _internal.ir    : read-only computed IR (for debugging; TODO: remove once stable)
```

**Principles in the tree shape:**
- Top level mixes firewall semantics (zones, nodes, rules) and mode/enable. This is what the user writes day-to-day.
- `objects.*` holds everything that maps one-to-one to nftables constructs. The sugared submodules accept either their natural shape or a raw nftypes value via coercion, so every primitive has a per-object escape hatch.
- `helpers.*` hosts opt-in infrastructure sub-modules. Each helper contributes to `rules.*` / `objects.*` / NixOS-native options the same way a user would.
- `ruleset` (full override) lives with the other Layer A escapes inside `objects`.

**References from rules to named objects use bare names**, e.g. `counter = "ssh"`, `ctHelper = "ftp"`, `match.srcSet = "blocklist"`. The `objects` namespace does not appear in references; resolution is done by the compiler against `networking.nftfw.objects.<kind>.<name>`.

## 4. Modes

One boolean switch controls the module's posture:

- **`authoritative = true`** (default). The module owns the kernel firewall. Sets `networking.nftables.flushRuleset = mkDefault true;` and `networking.firewall.enable = mkDefault false;`. Base chain policies default to drop/drop/accept on filter input/forward/output.
- **`authoritative = false`** (cooperative). The module coexists with other nftables contributors (other NixOS modules, docker, etc.). No flush; `networking.firewall` untouched. Base chain policies default to accept everywhere — drops in a base chain on a shared hook would suppress other contributors' accepts.

Rendering, pipeline, and primitives are **identical** in both modes. Only the two `mkDefault` settings and the policy defaults differ.

**`objects.ruleset` in each mode:** if set, its nftypes value is rendered to text and appended to `networking.nftables.ruleset` — same destination in both modes. NixOS's native ruleset composition then concatenates it with the generated per-table `content`. Use this for nftables constructs the module does not model (e.g., a hand-authored `table netdev ingress-extra { … }`) or to take complete authorship of the ruleset when also setting `authoritative = true` and clearing `objects.tables`.

## 5. Zones and nodes

### Zone submodule

```
networking.nftfw.zones.<name> = {
  parent          : nullOr str                        # hierarchy; null = root
  interfaces      : listOf str                         # iifname/oifname members
  addresses.ipv4  : listOf (libnet.ipv4 | ipv4Cidr)
  addresses.ipv6  : listOf (libnet.ipv6 | ipv6Cidr)
  conntrackZone   : nullOr int                         # multi-WAN conntrack isolation
  ingressExpression : nullOr rawNftypesExpr            # escape — replaces auto-derivation
  egressExpression  : nullOr rawNftypesExpr
  comment         : nullOr str
}
```

**Membership semantics** (unless overridden by expression):
- Ingress: `iifname ∈ interfaces` OR `saddr ∈ addresses.ipv4 ∪ addresses.ipv6`.
- Egress: analogously with `oifname` / `daddr`.
- Parent is AND-ed: a child's effective predicate is child-predicate AND parent-predicate. Children are subsets.
- If `ingressExpression` is set, **`interfaces` and `addresses` are ignored for ingress entirely** — the expression is the predicate. Same asymmetry for `egressExpression`. The user is taking over predicate construction for that direction; the sugar fields are silent for that direction only.

**Built-in zones** (always present, user-overridable):
- `local` — the host itself. Used as `to = "local"` (input chain) and `from = "local"` (output chain).
- `any` — matches everything. Short-circuits the zone predicate to true.

**Validation:**
- Zone names don't clash with node names.
- Parent exists and hierarchy is acyclic.
- Child's families are consistent with parent's membership (unless `ingressExpression` overrides).
- Addresses validated through libnet types.

### Node submodule

```
networking.nftfw.nodes.<name> = {
  zone            : str                        # required — parent zone
  address.ipv4    : nullOr libnet.ipv4
  address.ipv6    : nullOr libnet.ipv6
  comment         : nullOr str
}
```

**Semantics:**
- A node materializes internally as a synthetic child zone of its `zone`, membership = `/32` (ipv4) and `/128` (ipv6).
- Wherever a zone name is accepted in a rule's `from`/`to`, a node name is accepted identically.
- Nodes are usable as NAT targets (`to = "webserver:80"` resolves to the node's address at render time).

**Validation:** `zone` references an existing zone; node name doesn't clash with any zone name; address (if set) is in the parent zone's address range (libnet.cidr.contains check).

### Family scoping behavior

A zone's applicable families are derived from what it declares:

- `interfaces` only → family-agnostic (renders in every table).
- `addresses.ipv4` only → ipv4-applicable.
- `addresses.ipv6` only → ipv6-applicable.
- both → dual-stack.
- `ingressExpression`/`egressExpression` set → user-asserted; predicate rendered as-is.

For each (rule × target table) pair, the compiler emits only the family-applicable subset of the zone predicate. For dual-stack zones emitting into `inet`/`netdev`/`bridge`, **two rules** are produced (one per family) because nftables does not allow OR-ing `ip saddr` and `ip6 saddr` in a single rule.

A rule that applies to families the target table does not support is skipped for that table with an eval-time warning.

## 6. Rules

### Common rule fields

Every kind-typed rule submodule (`rules.filter.*`, `rules.icmp.*`, …) builds on a common core:

```
{
  enable          : bool = true
  comment         : nullOr str
  priority        : nullOr int                 # ordering within dispatched chain
  from            : str | listOf str           # zone/node names; "any" wildcard
  to              : str | listOf str           # same (kinds that use dest dispatch)
  tables          : nullOr listOf str          # F3 emission restriction; null = auto

  match = {
    srcAddresses.{ipv4,ipv6} : listOf ...
    dstAddresses.{ipv4,ipv6} : listOf ...
    srcSet                   : nullOr str       # → objects.sets.<name>
    dstSet                   : nullOr str
    srcPorts.{tcp,udp}       : listOf (port | portRange)
    dstPorts.{tcp,udp}       : listOf (port | portRange)
    protocol                 : nullOr str
    tcpFlags                 : nullOr str
    ct.state                 : listOf enum
    ct.direction             : nullOr enum
    mark                     : nullOr (int | str)
    extraMatch               : listOf rawNftypesExpr
  }

  # statement refs — by name or inline
  counter         : nullOr (bool | str | rawCounterObj)
  log             : nullOr ({ prefix?, level?, group?, flags? } | bool)
  limit           : nullOr (str | inline)
  quota           : nullOr (str | inline)
  ctHelper        : nullOr str
  ctTimeout       : nullOr str
  ctExpectation   : nullOr str
  synproxy        : nullOr (str | inline)
  secmark         : nullOr str
  flowtable       : nullOr str
  tunnel          : nullOr str
  meter           : nullOr { key, stmt, size?, name? }
  connectionLimit : nullOr { count, inv? }
  extraStatements : listOf rawNftypesStatement

  verdict         : nullOr enum                # "accept" | "drop" | "reject" | "continue" | "return"
  jumpTo          : nullOr str                 # mutually exclusive with verdict/gotoTo
  gotoTo          : nullOr str
}
```

### Kind-specialized fields

- **`rules.filter`** — full common set. Default `verdict = "accept"`.
- **`rules.icmp`** — adds `icmp.v4Types : listOf enum` and `icmp.v6Types : listOf enum`. Renders per family; dual-stack zones auto-split.
- **`rules.mangle`** — adds `setMark : nullOr int`, `setDscp : nullOr (int | enum)`. No `to` (prerouting is source-only). No default verdict.
- **`rules.dnat`** — adds `forwardTo : str | endpoint`. Accepts `"webserver:80"` (node), `"192.0.2.1:8080"` (literal endpoint), `":8080"` (port-only). Verdict hardcoded to `dnat` with the resolved target.
- **`rules.snat`** — adds `translateTo : nullOr (str | endpoint)`. `null` → masquerade; else `snat to <target>`.
- **`rules.redirect`** — adds `redirectTo : port`. Verdict hardcoded to `redirect to :<port>`.

### Chain-centric escape

For rules that don't fit a kind:

```
networking.nftfw.objects.chains.<name> = {
  table     : str                       # hosting objects.tables.<name>
  type      : nullOr enum               # "filter" | "nat" | "route" — base chains only
  hook      : nullOr enum               # "prerouting" | "input" | "forward" | "output" |
                                         # "postrouting" | "ingress" | "egress"
  priority  : nullOr int                # base chains only
  policy    : nullOr enum               # "accept" | "drop" — base chains only
  devices   : listOf str                # netdev/bridge ingress chains
  comment   : nullOr str
  rules     : listOf ruleFragment       # ordered list; same match/statement/verdict shape
}
```

A `ruleFragment` uses the same match and statement fields as a kind-typed rule, but without `from`/`to` dispatch — the user is placing the rule explicitly. `match.from` / `match.to` are available as ordinary matches if zone filtering is still wanted.

The `rules` field is a **list**, not an attrset: order is preserved and becomes the order of rules inside the emitted chain. Priority bands do not apply to chain-centric rules (the user is already expressing explicit order).

### Dispatch — kind to chain

Chain placement is derived from `(kind, from, to)`:

| Kind | Condition | Chain |
|---|---|---|
| filter / icmp | `to == "local"` and `from != "local"` | input |
| filter / icmp | `from == "local"` and `to != "local"` | output |
| filter / icmp | neither side is `"local"` | forward |
| filter / icmp | both sides `"local"` | output (loopback) |
| mangle | — | mangle-prerouting |
| dnat | — | nat-prerouting |
| redirect | — | nat-prerouting |
| snat | — | nat-postrouting |

Users can override via `match.chain = "<name>"` on a rule fragment (through the chain-centric escape) or by placing the rule directly in `objects.chains.<name>.rules`.

### Priority bands (within a dispatch chain)

| Band | Typical use |
|---|---|
| 1–99 | Pre-dispatch infrastructure (bogons, martian drops, ct state) |
| 100–499 | Early management |
| 500 | Default for user rules |
| 501–899 | Late management |
| 900–999 | Deny / log-and-drop |

Child-zone dispatch jumps are emitted between band 99 and band 100 of the parent's dispatch chain.

## 7. Emission and scoping (F3)

Tables are **emission targets**. Zones, nodes, rules, sets, maps, and named objects are **global** declarations that materialize into tables based on family compatibility.

### Table submodule

```
networking.nftfw.objects.tables.<name> = {
  family   : enum ["ip" "ip6" "inet" "arp" "bridge" "netdev"]
  flags    : listOf enum ["dormant" "owner" "persist"]
  comment  : nullOr str
  extraContent : nullOr rawNftypesTableBody          # appended verbatim to body

  baseChains = {
    input             : nullOr { priority, policy, extraRules }
    forward           : nullOr { priority, policy, extraRules }
    output            : nullOr { priority, policy, extraRules }
    natPrerouting     : nullOr { priority, extraRules }
    natPostrouting    : nullOr { priority, extraRules }
    manglePrerouting  : nullOr { priority, extraRules }
    ingress           : nullOr { priority, devices, extraRules }
    egress            : nullOr { priority, devices, extraRules }
  }
}
```

### Lazy default table

If the user declares zero tables but has rules that need a target, the compiler synthesizes `main = { family = "inet"; };` automatically. No synthesis if the user declares any table or has no rules.

### Auto-scoping

Every rule/object/set/map has an applicable-family set (see §5 and tables below) and an optional explicit `tables : listOf str`. Resolution per target table T:

1. **`tables` explicit** — emit into every named T that exists and has a compatible family. Warn on missing names; eval-error on incompatible families.
2. **`tables` unset** — emit into every declared table whose family is in the applicable-family set.

**Applicable-family sets:**

| Declaration | Applicable families | Notes |
|---|---|---|
| `sets.<X>` type `ipv4_addr` | ip, inet, netdev, bridge | L3-specific |
| `sets.<X>` type `ipv6_addr` | ip6, inet, netdev, bridge | |
| `sets.<X>` other types | all | |
| `maps.<X>` | — | by key type, per sets |
| counters, quotas, limits, secmarks, ct.* | all | |
| flowtables | ip, ip6, inet | |
| synproxies, tunnels | ip, ip6, inet | |
| filter / icmp rules | depends on zones used | auto-split per §5 |
| dnat/snat/redirect rules | ip, ip6, inet | NAT requires L3 |
| mangle rules | ip, ip6, inet, netdev | |

### Per-table instance materialization

Sets/maps/named-objects are table-scoped in nftables. A single `sets.<X>` declaration emits one kernel set per target table. The compiler keeps the elements in sync; users see a single logical object, the kernel sees N instances with the same name. References (`@<X>`) resolve to the instance in the same table as the referring rule.

### Default policies

**Authoritative:**
| Chain | Policy |
|---|---|
| filter input | drop |
| filter forward | drop |
| filter output | accept |
| nat prerouting/postrouting | accept |
| mangle prerouting | accept |

**Cooperative:** all base chains default to `accept`. Drops in a shared-hook base chain would suppress other contributors' accepts and break coexistence.

Per-chain override: `objects.tables.<name>.baseChains.<hook>.policy`.

## 8. Compilation pipeline (Approach 3 — hybrid)

```
raw options
  │
  ▼
[1] Collect & coerce
  │     helpers lift their contributions into rules/objects;
  │     bare strings coerced to lists; defaults applied
  ▼
[2] Validate
  │     ref existence (zones, nodes, sets, maps, counters, limits,
  │     chains, tables); zone hierarchy acyclic; priority sanity;
  │     nftypes schema checks per primitive
  ▼
[3] Build zone graph (IR)                          ─┐
  │     { zones: [{ name, familySet, perFamily       │
  │       predicate, parent, descendants,            │
  │       ingressExpr, egressExpr }],                │
  │       nodeZones: [...] }                        │
  ▼                                                 │
[4] Build table plan (IR)                          │  IR stages
  │     { tables: [{ name, family,                  │  (structural)
  │       neededBaseChains, objectsEmitted }] }     │
  │     lazy `main` synthesis here                  │
  ▼                                                 │
[5] Resolve rule emission (IR)                     │
  │     per (rule × applicable table):              │
  │     { rule-id, table, chain, family,            │
  │       effective-predicates, resolved-refs }     │
  │     dual-stack split happens here               │
  ▼                                                 │
[6] Generate dispatch (IR)                         │
  │     per (table × major-chain): per-zone         │
  │     subchains, hierarchy jumps, priority-band   │
  │     slotting, pre/post-dispatch infrastructure  │
  ▼                                                ─┘
[7] Kind-specific rendering (direct)               ─┐
  │     each rule kind's render function consumes    │  Direct
  │     resolved records → nftypes statements       │  composition
  ▼                                                 │
[8] Object rendering (direct)                      │
  │     sets/maps/counters/…/tunnels → nftypes      │
  │     via nftlib.dsl helpers; per-table           │
  │     instance materialization                    │
  ▼                                                ─┘
[9] Table assembly
  │     compose each target table as an nftypes
  │     table value (chains + rules + objects)
  ▼
[10] Emit
       nftlib.toText per table
       → networking.nftables.tables.<name>.content
       objects.ruleset (if any)
       → networking.nftables.ruleset
       mode-specific mkDefault lines
```

Stages 3–6 form the **IR**: plain attrsets/lists with a documented shape, inspectable from tests and tooling. Stages 7–8 are **direct composition**: each kind has its own render function that consumes resolved records without caring about the IR's internal structure.

### Dispatch mechanism (Mechanism A — per-zone chains)

For each major base chain in each target table, the compiler creates per-zone dispatch subchains (e.g. `input-from-wan`, `input-from-lan`, `input-from-trusted`). The base chain contains:

```nft
chain input {
  type filter hook input priority 0; policy drop;

  # pre-dispatch (priority 1-99) — global infra
  ct state established,related accept

  # dispatch by source zone
  iifname "eth0" jump input-from-wan
  ip saddr @lan-addrs-v4 jump input-from-lan
  ip6 saddr @lan-addrs-v6 jump input-from-lan

  # post-dispatch (priority 900+)
  log prefix "DROP: " level info
  counter drop
}

chain input-from-lan {
  # zone-lan pre-hierarchy (priority 1-99)
  ip saddr @bogon-v4 drop

  # jump to child zone dispatch
  ip saddr @trusted-addrs-v4 jump input-from-trusted

  # zone-lan post-hierarchy (priority 100+)
  tcp dport 22 accept
}

chain input-from-trusted {
  # trusted-only rules
  tcp dport 3306 accept
}
```

Chosen over verdict-map dispatch because: readable output, hierarchy emerges naturally from chain-to-chain jumps, family-agnostic, mixed interface/address zones render cleanly. At very large zone counts (hundreds), a vmap variant can be added behind an internal toggle and swapped in as an IR pass.

### Extension points

- **New rule kind.** A sub-module declares the submodule type under `rules.<kind>.<name>`, registers a render function in the internal renderer registry, and optionally adds stage-2 assertions. Stages 3–6 handle the new kind uniformly via `(kind, from, to)` placement.
- **New helper.** Contributes to `rules.*` / `objects.*` / NixOS-native options through ordinary option setting. No hook into the pipeline — helpers run before stage 1.
- **Cross-cutting behavior.** A sub-module registers an IR pass at a specific stage slot (`_passes.post-resolve = [ myPass ]`). The pass receives the IR, returns a modified IR. Used sparingly.

### Internal interfaces

- `_internal.ir` — read-only computed option exposing the IR after stage 6. For debugging and downstream tooling. **TODO: remove once the IR shape stabilizes.**
- `_internal.tables.<name>.content` — mirrors what goes to `networking.nftables.tables.<name>.content` without triggering a rebuild.

## 9. Helpers

Each helper lives in its own file under `modules/helpers/` and contributes to `rules.*` / `objects.*` / NixOS-native options via normal option setting.

| Helper | Effect | Default |
|---|---|---|
| `stopRuleset` | Sets `networking.nftables.stopRuleset` to a minimal-safe ruleset (loopback, est/rel, configurable `keepAlivePorts`). | enable = authoritative |
| `kernelHardening` | Sets `boot.kernel.sysctl` for `net.ipv{4,6}.conf.*.rp_filter`, `accept_redirects`, `accept_source_route`, `log_martians`, `icmp_echo_ignore_broadcasts`. | opt-in |
| `flowOffload` | Declares `objects.flowtables.offload` and adds `rules.filter` entries that enroll matching traffic. Options: `zones`, `interfaces`, `hardware`. | opt-in |
| `rpfilter` | Adds `rules.filter` entries using `fib saddr oif` to drop packets from the wrong interface. Options: `strict`, `exemptInterfaces`. | opt-in |
| `conntrackBaseline` | Adds `rules.filter` entries: accept est/rel at priority 100; drop invalid at priority 100. | enable = authoritative |
| `loopbackAccept` | Adds `rules.filter` for `iifname = "lo"` at priority 100. | enable = authoritative |
| `ipForwarding` | Sets `net.ipv4.ip_forward` / `net.ipv6.conf.all.forwarding` sysctls. | opt-in |
| `defaults` | Meta-helper — imports `stopRuleset` + `conntrackBaseline` + `loopbackAccept` bundle as a one-line "sensible defaults". | opt-in import |

No helper has a pipeline-level hook; all contribute at the options layer.

## 10. Repo layout

```
/
├── flake.nix                  # inputs: nixpkgs, nix-libnet, nix-nftypes
├── flake.lock
├── README.md
├── TODO.md                    # includes "remove _internal.ir once stable"
│
├── module.nix                 # top-level aggregator imports modules/*
├── modules/
│   ├── options.nix            # top-level options (enable, authoritative)
│   │
│   ├── firewall/              # zones, nodes, rule kinds
│   │   ├── zones.nix
│   │   ├── nodes.nix
│   │   ├── rules-common.nix   # shared fields + ruleFragment type
│   │   └── rules/
│   │       ├── filter.nix
│   │       ├── icmp.nix
│   │       ├── mangle.nix
│   │       ├── dnat.nix
│   │       ├── snat.nix
│   │       └── redirect.nix
│   │
│   ├── objects/               # tables, chains, sets, maps, stateful objects
│   │   ├── tables.nix
│   │   ├── chains.nix
│   │   ├── sets.nix
│   │   ├── maps.nix
│   │   ├── stateful.nix       # counters, quotas, limits
│   │   ├── ct.nix             # ct.helpers, ct.timeouts, ct.expectations
│   │   ├── flowtables.nix
│   │   ├── secmarks.nix
│   │   ├── synproxies.nix
│   │   ├── tunnels.nix
│   │   └── ruleset.nix        # full-override passthrough
│   │
│   ├── pipeline/              # compilation stages 1–10
│   │   ├── default.nix
│   │   ├── collect.nix
│   │   ├── validate.nix
│   │   ├── ir-zones.nix
│   │   ├── ir-tables.nix
│   │   ├── ir-rules.nix
│   │   ├── ir-dispatch.nix
│   │   ├── render-rules.nix
│   │   ├── render-objects.nix
│   │   ├── assemble.nix
│   │   └── emit.nix
│   │
│   └── helpers/
│       ├── stop-ruleset.nix
│       ├── kernel-hardening.nix
│       ├── flow-offload.nix
│       ├── rpfilter.nix
│       ├── conntrack-baseline.nix
│       ├── loopback-accept.nix
│       ├── ip-forwarding.nix
│       └── defaults.nix
│
├── lib/                       # internal helpers (not user-facing)
│   ├── zone-predicate.nix
│   ├── family.nix
│   ├── refs.nix
│   └── priority-bands.nix
│
├── tests/
│   ├── eval/                  # pure-eval assertions
│   ├── ir/                    # golden IR snapshots
│   ├── render/                # expected-text snapshots
│   ├── assertions/            # negative tests (each assertion paired)
│   ├── integration/           # unshare -rn nft -c -f acceptance
│   └── vm/                    # NixOS VM tests
│
└── docs/
    ├── ARCHITECTURE.md        # layer split, pipeline, extension points
    └── superpowers/
        └── specs/
            └── 2026-04-24-nixos-nftfw-design.md
```

## 11. Testing strategy

- **Pure-eval** — each pipeline stage in isolation; fabricated IR inputs; assert outputs.
- **Golden IR snapshots** — pin stages 3–6 IR for a corpus: single-host, fleet-member, edge-router, multi-table, dual-stack, hierarchy-heavy. Regressions surface as IR diffs.
- **Render snapshots** — pin expected text output for the same corpus. Catches renderer changes without VM boots.
- **Assertion tests** — each stage-2 assertion paired with a config that triggers it and one that doesn't.
- **Integration** — generated text through `unshare -rn nft -c -f`. Catches anything the text renderer emits that the kernel rejects.
- **VM tests** — small set: single-host firewall, 3-VM router with NAT, zone hierarchy, cooperative-mode-with-extra-table. CI only.

All wired into `nix flake check`.

## 12. Commit plan

~23 self-contained commits, ordered so each is independently reviewable.

1. Project skeleton — `flake.nix`, `README.md`, `TODO.md`, `.gitignore`. Inputs locked.
2. Empty module aggregator — `module.nix`, `modules/options.nix` with `enable` + `authoritative`.
3. Namespace stubs — `modules/firewall/*.nix` and `modules/objects/*.nix` with empty submodules; presence tests.
4. Zone submodule — `firewall/zones.nix` with libnet-backed address types; eval tests.
5. Node submodule — `firewall/nodes.nix`; eval tests.
6. Layer A primitives — sets, maps, counters, quotas, limits (grouped by affinity into ~3 commits); eval tests each.
7. ct, flowtables, secmarks, synproxies, tunnels (grouped as above).
8. Tables submodule — `objects/tables.nix` with base-chain defaults; eval tests.
9. Chains submodule — `objects/chains.nix` (R4 escape).
10. Common rule fields + ruleFragment type — `firewall/rules-common.nix`.
11. Kind-typed rule submodules — one commit per kind (filter, icmp, mangle, dnat, snat, redirect).
12. Pipeline stages 1–2 — collect + validate; eval tests; negative tests.
13. Pipeline stage 3 — zone graph IR; golden tests.
14. Pipeline stage 4 — table plan IR with lazy `main`; golden tests.
15. Pipeline stage 5 — rule emission resolution; dual-stack split; golden tests.
16. Pipeline stage 6 — dispatch generation; hierarchy jumps; golden tests.
17. Stage 7 — kind renderers; one commit per kind; render-snapshot tests.
18. Stage 8 — object renderers; snapshot tests.
19. Stages 9–10 — assembly + emit; first integration test.
20. Authoritative-mode glue — `flushRuleset` + `firewall.enable` mkDefault wiring.
21. First helper — `loopback-accept.nix`; proves helper extension end-to-end.
22. Remaining helpers — one commit each; `defaults.nix` last.
23. VM tests and architecture documentation.

## 13. Open questions / future work

- **vmap-based dispatch** — at large zone counts Mechanism A's dispatch scales O(Z). A vmap pass variant can be added behind an internal toggle once a real deployment pushes the limit.
- **Multi-address nodes (N2′)** — the single-address node model covers the intended use cases; a list-of-addresses extension is future-compatible if demand emerges (DNAT-to-multi would need an affinity policy).
- **Dynamic set updates** — `add @set { ip saddr timeout 1h }` in-kernel auto-bans are not in the initial surface. The mechanism is present in nftypes and can be exposed via an `action = { addToSet = "..." }` field on filter rules in a later commit.
- **Richer match sets** — destination-address set matching and port set matching on rules are planned for the initial rule surface; their exposure follows the same `match.dstSet` pattern as srcSet.
- **JSON rendering opt-in** — text is the default and covers the working surface. If a deployment hits a text-renderer edge case, JSON can be exposed via a user-facing `format` option at that point; until then it stays internal.
- **`_internal.ir` removal** — tracked in `TODO.md`. Remove when IR-consumer tooling has stabilized and snapshot tests are the single source of truth.
