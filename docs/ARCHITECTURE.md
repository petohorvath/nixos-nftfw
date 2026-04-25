# nixos-nftfw Architecture

**Spec:** `docs/specs/2026-04-24-nixos-nftfw-design.md` — read
that for full detail. This document is a navigational overview.

---

## 1. Overview

`nixos-nftfw` is a NixOS module that compiles user-declared firewall policy
into nftables configuration. It targets single-host workstations, multi-host
fleets, and edge routers equally, using only the NixOS module system for
composition — no custom template or fragment mechanism.

The module is built on two upstream Nix libraries:

- **nix-libnet** — pure-Nix networking primitives (addresses, CIDRs, ports,
  endpoints, MACs) with NixOS-module-compatible option types. Used for input
  validation.
- **nix-nftypes** — complete typed Nix representation of the nftables
  libnftables-JSON schema, plus a high-level DSL and text/JSON renderers.
  Used as the compilation target data model.

### Two-layer split

```
Layer B — firewall semantics          networking.nftfw.{zones,nodes,rules.*}
  |  zones, nodes, kind-typed rules
  |  compile to ↓
Layer A — nftables primitives         networking.nftfw.objects.*
  |  tables, chains, sets, maps, stateful objects
  |  render to ↓
nix-nftypes toText
  |
  ↓
networking.nftables.tables.<name>.content   (standard NixOS option)
  |
  ↓
nftables.service                            (kernel activation)
```

Users write almost entirely in Layer B. Layer A is the escape hatch when a
construct has no Layer B analog, and the direct target for advanced users who
want table/chain-level control without abandoning the module system.

---

## 2. Top-level option tree

```
networking.nftfw
├── enable          : bool
├── authoritative   : bool = true
│
│   # Layer B — firewall semantics
├── zones           : attrsOf zoneSubmodule
├── nodes           : attrsOf nodeSubmodule
├── rules
│   ├── filter      : attrsOf filterRuleSubmodule
│   ├── icmp        : attrsOf icmpRuleSubmodule
│   ├── mangle      : attrsOf mangleRuleSubmodule
│   ├── dnat        : attrsOf dnatRuleSubmodule
│   ├── snat        : attrsOf snatRuleSubmodule
│   └── redirect    : attrsOf redirectRuleSubmodule
│
│   # Layer A — nftables primitives
├── objects
│   ├── tables          : attrsOf tableSubmodule
│   ├── chains          : attrsOf chainSubmodule
│   ├── sets            : attrsOf setSubmodule
│   ├── maps            : attrsOf mapSubmodule
│   ├── counters        : attrsOf counterSubmodule
│   ├── quotas          : attrsOf quotaSubmodule
│   ├── limits          : attrsOf limitSubmodule
│   ├── ct
│   │   ├── helpers       : attrsOf ctHelperSubmodule
│   │   ├── timeouts      : attrsOf ctTimeoutSubmodule
│   │   └── expectations  : attrsOf ctExpectationSubmodule
│   ├── flowtables      : attrsOf flowtableSubmodule
│   ├── secmarks        : attrsOf secmarkSubmodule
│   ├── synproxies      : attrsOf synproxySubmodule
│   ├── tunnels         : attrsOf tunnelSubmodule
│   └── ruleset         : nullOr nftypesRulesetType   # full-override passthrough
│
│   # Opt-in infrastructure
└── helpers
    ├── stopRuleset       : { enable, keepAlivePorts, ... }
    ├── kernelHardening   : { enable, ... }
    ├── flowOffload       : { enable, zones, interfaces, hardware }
    ├── rpfilter          : { enable, strict, exemptInterfaces }
    ├── conntrackBaseline : { enable }
    ├── loopbackAccept    : { enable }
    ├── ipForwarding      : { enable, ipv4, ipv6 }
    └── defaults          : { enable }   # meta-bundle
```

**Key conventions:**

- `rules.*` fields reference `objects.*` by bare name (`counter = "ssh"`,
  `ctHelper = "ftp"`). The compiler resolves names against the objects
  namespace.
- Every `objects.*` submodule accepts either its natural shape or a raw
  nftypes value via coercion — per-object escape with no module-level
  buy-in required.
- Helpers contribute to `rules.*` / `objects.*` / NixOS-native options
  through ordinary option setting. They have no pipeline-level hook.

---

## 3. Modes

One boolean controls the module's kernel posture:

### Authoritative (default: `authoritative = true`)

The module owns the kernel firewall completely.

- Sets `networking.nftables.flushRuleset = mkDefault true`
- Sets `networking.firewall.enable = mkDefault false`
- Base chain policies default to **drop/drop/accept** (input/forward/output)
- `helpers.stopRuleset` and `helpers.conntrackBaseline` enabled by default

Use this for any host where nftfw is the sole firewall manager.

### Cooperative (`authoritative = false`)

The module coexists with other nftables contributors (other NixOS modules,
container runtimes, etc.).

- No flush; `networking.firewall` left untouched
- Base chain policies default to **accept** everywhere — drops in a shared
  base chain would suppress other contributors' accepts

Rendering, the compilation pipeline, and all primitives are **identical** in
both modes. Only the two `mkDefault` assignments and the policy defaults
differ.

---

## 4. Eval-time validation via nix-libnet

nix-libnet supplies networking-aware NixOS option types — `ipv4`, `ipv6`,
`cidr`, `ipv4Cidr`, `ipv6Cidr`, `port`, `portRange`, `endpoint`, and others —
that reject malformed input at module evaluation rather than at activation time.
`nixos-nftfw` uses these types throughout the Layer B option surface to catch
bad addresses, CIDRs, and ports as early as possible in the development loop.

### Where libnet types are applied

**Zones** (`networking.nftfw.zones.<name>`)
- `addresses.ipv4` — `listOf libnet.types.ipv4Cidr`
- `addresses.ipv6` — `listOf libnet.types.ipv6Cidr`

**Nodes** (`networking.nftfw.nodes.<name>`)
- `address.ipv4` — `nullOr libnet.types.ipv4` (single address, no prefix)
- `address.ipv6` — `nullOr libnet.types.ipv6`

**Rule match fields** (shared across filter, mangle, ICMP, DNAT, SNAT, redirect)
- `srcAddresses.ipv4`, `dstAddresses.ipv4` — `listOf libnet.types.ipv4Cidr`
- `srcAddresses.ipv6`, `dstAddresses.ipv6` — `listOf libnet.types.ipv6Cidr`
- `srcPorts.tcp`, `srcPorts.udp`, `dstPorts.tcp`, `dstPorts.udp` — `listOf (either libnet.types.port libnet.types.portRange)`

**Redirect rules** (`networking.nftfw.rules.redirect.<name>`)
- `redirectTo` — `libnet.types.port`

**Tunnels** (`networking.nftfw.objects.tunnels.<name>`)
- `src-ipv4`, `dst-ipv4` — `nullOr libnet.types.ipv4`
- `src-ipv6`, `dst-ipv6` — `nullOr libnet.types.ipv6`
- `sport`, `dport` — `nullOr libnet.types.port`

**Stop-ruleset helper** (`networking.nftfw.helpers.stopRuleset`)
- `keepAlivePorts` — `listOf libnet.types.port`

### Where validation is intentionally deferred

Two areas remain typed as plain `str`:

- **DNAT `forwardTo` and SNAT `translateTo`** accept either a literal endpoint
  (e.g. `"192.0.2.1:8080"`) or a bare `node-name:port` reference (e.g.
  `"backend:8080"`). Tightening these to `libnet.types.endpoint` would reject
  the node-name forms before the renderer has a chance to resolve them. They
  remain `str` until the node-name resolution logic lands; this is tracked in
  `TODO.md`.

- **Set and map `elements`** are typed `unspecified`. The valid element shape
  depends on the parent object's `type` field (e.g. `ipv4_addr`, `inet_service`,
  concatenated types). Element-level validation will arrive together with the
  renderer that interprets them.

### Wiring

`module.nix` receives `libnet` as a flake-level argument, calls
`libnet.withLib lib` to bind it to the module's `lib`, and exposes the result
via `_module.args.libnet`. Every submodule that needs networking types declares
`{ libnet, ... }:` in its inner function and references types as
`libnet.types.ipv4Cidr`, `libnet.types.port`, etc. No submodule imports libnet
directly; all access goes through the module argument.

### Failure mode

When a malformed value is supplied — for example
`addresses.ipv4 = [ "999.0.0.1/24" ]` — `nixos-rebuild switch` (or
`nix flake check`) fails at evaluation time with a libnet-generated error
message that names the offending option path. This is significantly earlier
than a failure at `nft -f` during service activation, which would only surface
after the build completed and the unit started.

---

## 5. Compilation pipeline

```
networking.nftfw.*
        │
        ▼
  [1] Collect & coerce ──────── helpers lift contributions; defaults applied
        │
        ▼
  [2] Validate ──────────────── ref existence, zone acyclicity, schema checks
        │
        ▼
  ┌─────────────────── IR stages (plain attrsets, inspectable) ────────────┐
  │     ▼                                                                   │
  │ [3] Zone graph IR ─── { zones, per-family predicates, hierarchy }      │
  │     ▼                                                                   │
  │ [4] Table plan IR ─── { tables, base chains needed, lazy main synth }  │
  │     ▼                                                                   │
  │ [5] Rule emission IR ─ per (rule × table): chain, family, predicates,  │
  │                         resolved refs; dual-stack split here            │
  │     ▼                                                                   │
  │ [6] Dispatch IR ─────── per (table × chain): per-zone subchains,      │
  │                          hierarchy jumps, priority-band slotting        │
  └────────────────────────────────────────────────────────────────────────┘
        │
        ▼
  ┌─────── Direct composition ─────────────────────────────────────────────┐
  │ [7] Kind rendering ── each rule kind's render fn → nftypes statements  │
  │ [8] Object rendering ─ sets/maps/counters/… → nftypes per-table inst.  │
  └────────────────────────────────────────────────────────────────────────┘
        │
        ▼
  [9] Table assembly ────── compose each table as an nftypes table value
        │
        ▼
 [10] Emit ────────────────  nftlib.toText → networking.nftables.tables.*
                             objects.ruleset → networking.nftables.ruleset
```

**Stage breakdown:**

| Stage | File | Role |
|-------|------|------|
| 1 | `pipeline/collect.nix` | Coerce bare strings to lists; apply option defaults; materialize helper contributions |
| 2 | `pipeline/validate.nix` | Assert ref existence, acyclicity, family consistency, nftypes schema |
| 3 | `pipeline/ir-zones.nix` | Build zone graph with per-family membership predicates and parent chains |
| 4 | `pipeline/ir-tables.nix` | Enumerate target tables; record which base chains are needed; synthesize lazy `main` |
| 5 | `pipeline/ir-rules.nix` | Resolve each rule against each applicable table; apply dual-stack split for mixed-family zones |
| 6 | `pipeline/ir-dispatch.nix` | Generate per-zone subchain structure, hierarchy jump order, priority-band assignments |
| 7 | `pipeline/render-rules.nix` | Call the per-kind render function for each resolved rule record |
| 8 | `pipeline/render-objects.nix` | Render sets/maps/counters/… as nftypes objects; one instance per target table |
| 9 | `pipeline/assemble.nix` | Compose rendered rules and objects into nftypes table values |
| 10 | `pipeline/emit.nix` | Call `nftlib.toText`; write to NixOS options; apply mode-specific `mkDefault` lines |

Stages 3–6 form the **IR**: inspectable plain attrsets exposed read-only at
`networking.nftfw._internal.ir` for debugging and snapshot tests. Stages 7–8
are **direct composition**: each kind render function consumes resolved IR
records without touching the IR's internal structure.

---

## 6. Dispatch model

For each major base chain in each target table, the compiler creates
per-zone subchains. The base chain dispatches to them by zone predicate,
then applies priority-banded rules within each subchain:

```nft
chain input {
  type filter hook input priority 0; policy drop;

  # pre-dispatch band (1–99): global infrastructure
  ct state established,related accept

  # zone dispatch
  iifname "eth0" jump input-from-wan
  ip saddr @lan-addrs-v4 jump input-from-lan

  # post-dispatch band (900–999): log-and-drop
  log prefix "DROP: " level info drop
}

chain input-from-lan {
  # child-zone hierarchy jump (between band 99 and 100)
  ip saddr @trusted-addrs-v4 jump input-from-trusted

  # user rules in band 500
  tcp dport 22 accept
}

chain input-from-trusted {
  tcp dport 3306 accept
}
```

**Priority bands:**

| Band | Purpose |
|------|---------|
| 1–99 | Pre-dispatch infrastructure (bogons, ct state, rpfilter) |
| 100–499 | Early management |
| 500 | Default for user rules |
| 501–899 | Late management |
| 900–999 | Deny / log-and-drop |

Hierarchy jumps are inserted between band 99 and 100 of the parent subchain.
Child zones are strict subsets of their parents, so hierarchy is always
correct without extra predicates.

---

## 7. Family scoping (F3)

Zones and rules are **global declarations**. Tables are **emission targets**.
The compiler determines which declarations land in which tables based on
family compatibility.

**Zone family derivation:**

| Zone declares | Applicable families |
|---------------|-------------------|
| `interfaces` only | all (family-agnostic) |
| `addresses.ipv4` only | ip, inet, netdev, bridge |
| `addresses.ipv6` only | ip6, inet, netdev, bridge |
| both ipv4 and ipv6 | dual-stack: both sets |
| raw expression | user-asserted; rendered as-is |

For dual-stack zones targeting `inet` / `netdev` / `bridge` tables, the
compiler emits **two rules** (one per family) because nftables does not
allow OR-ing `ip saddr` and `ip6 saddr` in a single rule.

**Emission resolution per rule:**

1. If `tables = [ "name" ... ]` is set explicitly, emit into each named
   table that exists and has a compatible family. Warn on missing names;
   eval-error on incompatible families.
2. If `tables` is unset (`null`), emit into every declared table whose
   family is in the rule's applicable-family set.

A rule that applies to families the target table does not support is silently
skipped for that table.

**Per-table object instances:** Sets, maps, and named objects are table-scoped
in nftables. A single `objects.sets.<X>` declaration produces one kernel set
per target table. The compiler keeps elements in sync; references (`@<X>`)
in rules always resolve to the instance in the same table as the rule.

**Lazy `main` table:** If the user declares zero tables but has rules, the
compiler synthesizes `objects.tables.main = { family = "inet"; }`. No
synthesis occurs if any table is declared or if there are no rules.

---

## 8. Extension points

### Adding a new rule kind

1. Create `modules/firewall/rules/<kind>.nix`. Declare the submodule type
   under `rules.<kind>.<name>` using `rules-common.nix`'s shared fields as
   a base.
2. Register a render function in `modules/pipeline/renderers/`. The function
   receives a resolved rule record from stage 5 and returns a list of nftypes
   statements.
3. Optionally add stage-2 assertions in `pipeline/validate.nix` for any
   kind-specific constraints.

Stages 3–6 handle the new kind uniformly via `(kind, from, to)` chain
placement — no changes required there.

### Adding a new helper

Create `modules/helpers/<name>.nix`. Contribute to `rules.*`, `objects.*`,
or NixOS-native options through ordinary option setting. Import the file
from `modules/helpers/defaults.nix` or document it for manual import.
Helpers run entirely at the options layer, before stage 1.

### Adding an IR pass

A sub-module can register a function in `_passes.post-resolve` (or another
documented slot). The pass receives the stage-N IR attrset and returns a
modified IR. Use sparingly — the common cases do not require IR passes.

---

## 9. Testing strategy

All checks are wired into `nix flake check`.

| Layer | Location | What it covers |
|-------|----------|----------------|
| Pure-eval | `tests/eval/` | Each pipeline stage in isolation; fabricated inputs; assert output shape |
| Golden IR snapshots | `tests/ir/` | Pin stages 3–6 IR for a corpus of configs; regressions surface as IR diffs |
| Render snapshots | `tests/render/` | Pin expected nft text for the same corpus; catches renderer changes without a VM |
| Assertion tests | `tests/assertions/` | Each stage-2 assertion paired with a config that triggers it and one that does not |
| Integration | `tests/integration/` | Generated text piped through `unshare -rn nft -c -f`; catches text the kernel rejects |
| VM tests | `tests/vm/` | End-to-end: boot a NixOS VM with nftfw enabled, assert the ruleset is active |

Pure-eval, snapshot, and assertion tests are fast and run on every `nix
flake check`. Integration and VM tests are heavier but still part of CI.

---

## Repository layout

```
flake.nix                          # inputs: nixpkgs, nix-libnet, nix-nftypes
module.nix                         # aggregator; imports modules/*
modules/
  options.nix                      # enable, authoritative, _internal.ir
  firewall/                        # zones, nodes, rule kinds (Layer B)
  objects/                         # tables, chains, sets, maps, stateful (Layer A)
  pipeline/                        # stages 1–10
  helpers/                         # opt-in infrastructure helpers
lib/                               # internal helpers (zone-predicate, family, refs, bands)
tests/
  harness.nix                      # evalModules wrapper
  eval/, ir/, render/, assertions/, integration/, vm/
docs/
  ARCHITECTURE.md                  # this file
  specs/
    2026-04-24-nixos-nftfw-design.md  # full design spec
  plans/
    2026-04-24-nixos-nftfw.md         # implementation plan
```
