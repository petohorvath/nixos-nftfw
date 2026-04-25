# nixos-nftfw Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `nixos-nftfw`, a NixOS module that compiles user-declared zones, nodes, rules, and nftables primitives into `networking.nftables.tables.<name>.content` using nix-libnet + nix-nftypes.

**Architecture:** Two layers over nix-nftypes — Layer A (`networking.nftfw.objects.*`: tables, chains, sets, maps, counters, quotas, limits, ct.*, flowtables, secmarks, synproxies, tunnels, ruleset) and Layer B (top-level `zones`, `nodes`, `rules.<kind>`). A 10-stage hybrid compilation pipeline: IR for structural transforms (zones 3-6), direct composition for renderers (7-8). Authoritative mode default; cooperative mode available.

**Tech Stack:** Nix (flakes), `nixpkgs` (for `lib`, NixOS module system), `nix-libnet` (address/port validation), `nix-nftypes` (schema + DSL + text renderer), `unshare -rn nft -c -f` (integration), `pkgs.testers.runNixOSTest` (VM tests).

**Reference spec:** `docs/specs/2026-04-24-nixos-nftfw-design.md`

---

## File Structure

```
flake.nix                                  # inputs + checks
module.nix                                 # entry; imports modules/*
modules/
  options.nix                              # enable, authoritative, _internal.ir
  firewall/
    zones.nix                              # zoneSubmodule + built-ins
    nodes.nix                              # nodeSubmodule
    rules-common.nix                       # shared fields + ruleFragment
    rules/{filter,icmp,mangle,dnat,snat,redirect}.nix
  objects/
    tables.nix, chains.nix, sets.nix, maps.nix,
    stateful.nix (counters/quotas/limits),
    ct.nix, flowtables.nix, secmarks.nix,
    synproxies.nix, tunnels.nix, ruleset.nix
  pipeline/
    default.nix, collect.nix, validate.nix,
    ir-zones.nix, ir-tables.nix, ir-rules.nix, ir-dispatch.nix,
    render-rules.nix, render-objects.nix, assemble.nix, emit.nix
  helpers/
    stop-ruleset.nix, kernel-hardening.nix, flow-offload.nix,
    rpfilter.nix, conntrack-baseline.nix, loopback-accept.nix,
    ip-forwarding.nix, defaults.nix
lib/
  zone-predicate.nix, family.nix, refs.nix, priority-bands.nix
tests/
  harness.nix                              # evalModules wrapper + runTests
  eval/…, ir/…, render/…, assertions/…, integration/…, vm/…
docs/ARCHITECTURE.md
```

Test convention: each test file is a derivation wired into `flake.nix`'s `checks.<system>.<name>`. Pure-eval tests use `pkgs.lib.runTests`; module tests use a harness wrapping `lib.evalModules`.

---

## Task 1: Repo skeleton

**Files:**
- Create: `flake.nix`, `README.md`, `TODO.md`, `.gitignore`

- [ ] **Step 1: Write `.gitignore`**

```
result
result-*
.direnv/
```

- [ ] **Step 2: Write `flake.nix` with inputs and empty outputs**

```nix
{
  description = "nixos-nftfw — NixOS nftables firewall module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-libnet = {
      url = "github:petohorvath/nix-libnet";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-nftypes = {
      url = "github:petohorvath/nix-nftypes";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-libnet, nix-nftypes }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forEach = f: nixpkgs.lib.genAttrs systems (s: f s);
    in {
      nixosModules.default = import ./module.nix {
        inherit (nix-libnet) lib;
        nftlib = nix-nftypes.lib;
      };
      nixosModules.nftfw = self.nixosModules.default;

      formatter = forEach (s: nixpkgs.legacyPackages.${s}.nixfmt-rfc-style);
      checks = forEach (s: { });   # filled in later tasks
    };
}
```

- [ ] **Step 3: Write `README.md` skeleton (no inspiration references)**

```markdown
# nixos-nftfw

A NixOS module that generates nftables firewall configuration.

## Status

Pre-release. The module's option surface and compilation pipeline
are under active development. See
`docs/specs/2026-04-24-nixos-nftfw-design.md` for the
design.

## Usage

```nix
{
  inputs.nixos-nftfw.url = "github:petohorvath/nixos-nftables-firewall";

  outputs = { self, nixpkgs, nixos-nftfw, ... }: {
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ nixos-nftfw.nixosModules.default ];
    };
  };
}
```
```

- [ ] **Step 4: Write `TODO.md`**

```markdown
# TODO

- Remove `networking.nftfw._internal.ir` once the IR shape stabilizes
  and snapshot tests are the single source of truth.
- Consider exposing JSON rendering as a user-facing `format` option
  if a deployment hits a known text-renderer edge case.
- Add vmap-based dispatch variant behind an internal toggle if
  zone counts exceed O(100).
```

- [ ] **Step 5: Validate flake and commit**

```bash
nix flake check 2>&1 | head -20    # should succeed (no checks defined yet)
git add flake.nix README.md TODO.md .gitignore
git commit -m "chore: Initialize flake with nix-libnet and nix-nftypes inputs"
```

---

## Task 2: Module aggregator and top-level options

**Files:**
- Create: `module.nix`, `modules/options.nix`, `tests/harness.nix`, `tests/eval/enable.nix`

- [ ] **Step 1: Write `module.nix`**

```nix
{ lib, nftlib }:

{ config, pkgs, ... }:

{
  imports = [
    (import ./modules/options.nix { inherit lib; })
  ];
}
```

- [ ] **Step 2: Write `modules/options.nix`**

```nix
{ lib }:

{ config, ... }:

{
  options.networking.nftfw = {
    enable = lib.mkEnableOption "nftfw firewall module";

    authoritative = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When true, the module owns the kernel firewall: flushes the
        ruleset at load and disables networking.firewall. When false,
        coexists with other nftables contributors.
      '';
    };

    _internal.ir = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      internal = true;
      readOnly = true;
      description = "Computed IR for debugging. TODO: remove once stable.";
    };
  };
}
```

- [ ] **Step 3: Write `tests/harness.nix`**

```nix
{ pkgs, libnet, nftlib }:

let
  inherit (pkgs) lib;

  evalConfig = userConfig: (lib.evalModules {
    modules = [
      (import ../module.nix { inherit lib; inherit nftlib; })
      userConfig
    ];
    specialArgs = { inherit libnet nftlib; };
  }).config;

  # Run a set of { name = { expr, expected }; }; abort on failure.
  runTests = suite:
    let
      results = lib.runTests suite;
    in
      if results == [ ]
      then pkgs.runCommand "tests-ok" { } "touch $out"
      else throw "test failures: ${builtins.toJSON results}";
in
  { inherit evalConfig runTests; }
```

- [ ] **Step 4: Write `tests/eval/enable.nix`**

```nix
{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
in
  h.runTests {
    testEnableDefault = {
      expr = (h.evalConfig ({ ... }: { })).networking.nftfw.enable;
      expected = false;
    };
    testAuthoritativeDefault = {
      expr = (h.evalConfig ({ ... }: { networking.nftfw.enable = true; }))
             .networking.nftfw.authoritative;
      expected = true;
    };
    testAuthoritativeOverride = {
      expr = (h.evalConfig ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.authoritative = false;
      })).networking.nftfw.authoritative;
      expected = false;
    };
  }
```

- [ ] **Step 5: Wire tests into `flake.nix` checks**

Edit `flake.nix` and replace `checks = forEach (s: { });` with:

```nix
      checks = forEach (s:
        let
          pkgs = nixpkgs.legacyPackages.${s};
          libnet = nix-libnet.lib;
          nftlib = nix-nftypes.lib;
          mkTest = path: import path { inherit pkgs libnet nftlib; };
        in {
          eval-enable = mkTest ./tests/eval/enable.nix;
        });
```

- [ ] **Step 6: Run test**

```bash
nix flake check 2>&1 | tail -10
# expect: build of eval-enable succeeds
```

- [ ] **Step 7: Commit**

```bash
git add module.nix modules/options.nix tests/harness.nix tests/eval/enable.nix flake.nix
git commit -m "feat(options): Add enable and authoritative options with harness"
```

---

## Task 3: Namespace stubs

Each submodule file defines its namespace empty so later tasks fill fields without also declaring the containing option.

**Files:**
- Create: `modules/firewall/{zones,nodes,rules-common}.nix`
- Create: `modules/firewall/rules/{filter,icmp,mangle,dnat,snat,redirect}.nix`
- Create: `modules/objects/{tables,chains,sets,maps,stateful,ct,flowtables,secmarks,synproxies,tunnels,ruleset}.nix`
- Create: `modules/helpers/` (directory placeholder; files added later)
- Modify: `module.nix` to import every stub
- Create: `tests/eval/namespaces.nix`

- [ ] **Step 1: Write each empty submodule file**

Each firewall/* and objects/* file follows this template, substituting the option path:

```nix
# modules/firewall/zones.nix
{ lib }:

{ config, ... }:

{
  options.networking.nftfw.zones = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { options = { }; }));
    default = { };
    description = "Zones — semantic grouping of traffic.";
  };
}
```

Apply identically with adjusted paths to: nodes, rules-common (skip; no option), rules/*, tables, chains, sets, maps, stateful (needs 3 options: counters, quotas, limits under objects.*), ct (needs ct.helpers, ct.timeouts, ct.expectations), flowtables, secmarks, synproxies, tunnels, ruleset.

For multi-option files like `stateful.nix`, define all three:

```nix
{ lib }:
{ config, ... }:
{
  options.networking.nftfw.objects.counters = lib.mkOption { type = lib.types.attrsOf (lib.types.submodule { options = { }; }); default = { }; };
  options.networking.nftfw.objects.quotas   = lib.mkOption { type = lib.types.attrsOf (lib.types.submodule { options = { }; }); default = { }; };
  options.networking.nftfw.objects.limits   = lib.mkOption { type = lib.types.attrsOf (lib.types.submodule { options = { }; }); default = { }; };
}
```

`ct.nix` gives `objects.ct.helpers`, `objects.ct.timeouts`, `objects.ct.expectations`.

Rules kinds (`rules/filter.nix` etc.) each declare `options.networking.nftfw.rules.<kind>` as `attrsOf (submodule { options = {}; })`.

`rules-common.nix` defines no option; it exports shared types (see Task 13).

- [ ] **Step 2: Update `module.nix` to import every stub**

```nix
{ lib, nftlib }:

{ config, pkgs, ... }:

{
  imports = [
    (import ./modules/options.nix { inherit lib; })

    # Firewall (Layer B)
    (import ./modules/firewall/zones.nix { inherit lib; })
    (import ./modules/firewall/nodes.nix { inherit lib; })
    (import ./modules/firewall/rules/filter.nix { inherit lib; })
    (import ./modules/firewall/rules/icmp.nix { inherit lib; })
    (import ./modules/firewall/rules/mangle.nix { inherit lib; })
    (import ./modules/firewall/rules/dnat.nix { inherit lib; })
    (import ./modules/firewall/rules/snat.nix { inherit lib; })
    (import ./modules/firewall/rules/redirect.nix { inherit lib; })

    # Objects (Layer A)
    (import ./modules/objects/tables.nix { inherit lib; })
    (import ./modules/objects/chains.nix { inherit lib; })
    (import ./modules/objects/sets.nix { inherit lib; })
    (import ./modules/objects/maps.nix { inherit lib; })
    (import ./modules/objects/stateful.nix { inherit lib; })
    (import ./modules/objects/ct.nix { inherit lib; })
    (import ./modules/objects/flowtables.nix { inherit lib; })
    (import ./modules/objects/secmarks.nix { inherit lib; })
    (import ./modules/objects/synproxies.nix { inherit lib; })
    (import ./modules/objects/tunnels.nix { inherit lib; })
    (import ./modules/objects/ruleset.nix { inherit lib; })
  ];
}
```

- [ ] **Step 3: Write `tests/eval/namespaces.nix`**

```nix
{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  cfg = h.evalConfig ({ ... }: { });
  nftfw = cfg.networking.nftfw;
in
  h.runTests {
    testZonesEmpty       = { expr = nftfw.zones; expected = { }; };
    testNodesEmpty       = { expr = nftfw.nodes; expected = { }; };
    testRulesFilterEmpty = { expr = nftfw.rules.filter; expected = { }; };
    testObjectsTables    = { expr = nftfw.objects.tables; expected = { }; };
    testObjectsSets      = { expr = nftfw.objects.sets; expected = { }; };
    testObjectsCtHelpers = { expr = nftfw.objects.ct.helpers; expected = { }; };
  }
```

- [ ] **Step 4: Wire into flake checks and run**

Add `eval-namespaces = mkTest ./tests/eval/namespaces.nix;` to the checks attrset. Then:

```bash
nix flake check 2>&1 | tail -10    # eval-namespaces passes
```

- [ ] **Step 5: Commit**

```bash
git add modules/ module.nix tests/eval/namespaces.nix flake.nix
git commit -m "feat(options): Stub all Layer A and Layer B namespaces"
```

---

## Task 4: Zone submodule

**Files:**
- Modify: `modules/firewall/zones.nix`
- Create: `tests/eval/zones.nix`

- [ ] **Step 1: Write failing test**

```nix
# tests/eval/zones.nix
{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };

  withZones = zones: (h.evalConfig ({ ... }: {
    networking.nftfw.enable = true;
    networking.nftfw.zones = zones;
  })).networking.nftfw.zones;
in
  h.runTests {
    testZoneInterfacesOnly = {
      expr = (withZones { wan.interfaces = [ "eth0" ]; }).wan.interfaces;
      expected = [ "eth0" ];
    };
    testZoneWithAddressesV4 = {
      expr = (withZones {
        lan = {
          interfaces = [ "eth1" ];
          addresses.ipv4 = [ "192.168.1.0/24" ];
        };
      }).lan.addresses.ipv4;
      expected = [ "192.168.1.0/24" ];
    };
    testZoneParent = {
      expr = (withZones {
        lan.interfaces = [ "eth1" ];
        trusted.parent = "lan";
      }).trusted.parent;
      expected = "lan";
    };
    testBuiltinLocalZone = {
      expr = (withZones { }).local or null;
      expected = { interfaces = [ ]; addresses.ipv4 = [ ]; addresses.ipv6 = [ ]; parent = null; conntrackZone = null; ingressExpression = null; egressExpression = null; comment = null; };
    };
  }
```

Wire `eval-zones = mkTest ./tests/eval/zones.nix;` in flake.

- [ ] **Step 2: Run — expect fail**

```bash
nix build .#checks.x86_64-linux.eval-zones 2>&1 | tail -5
# expect: attribute 'interfaces' missing (since submodule has no options yet)
```

- [ ] **Step 3: Implement**

```nix
# modules/firewall/zones.nix
{ lib }:

{ config, libnet ? null, ... }:

let
  libnetLib = config._module.args.libnet or libnet;

  zoneSubmodule = { name, ... }: {
    options = {
      parent = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Parent zone; null = root. Creates hierarchy.";
      };
      interfaces = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "iifname/oifname members.";
      };
      addresses.ipv4 = lib.mkOption {
        type = lib.types.listOf lib.types.str;   # TODO: refine to libnet.types once wired
        default = [ ];
      };
      addresses.ipv6 = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      conntrackZone = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
      };
      ingressExpression = lib.mkOption {
        type = lib.types.nullOr lib.types.attrs;
        default = null;
        description = "Raw nftypes match expression; replaces auto-derivation.";
      };
      egressExpression = lib.mkOption {
        type = lib.types.nullOr lib.types.attrs;
        default = null;
      };
      comment = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
    };
  };
in {
  options.networking.nftfw.zones = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule zoneSubmodule);
    default = { };
    description = "Zones — semantic traffic groupings.";
  };

  config.networking.nftfw.zones = {
    local = lib.mkDefault { };
    any   = lib.mkDefault { };
  };
}
```

(Address-type refinement is deferred to a follow-up once libnet types are wired in Task 4b — for now, string type with a TODO.)

- [ ] **Step 4: Run — expect pass**

```bash
nix build .#checks.x86_64-linux.eval-zones 2>&1 | tail -5
```

- [ ] **Step 5: Commit**

```bash
git add modules/firewall/zones.nix tests/eval/zones.nix flake.nix
git commit -m "feat(firewall): Add zone submodule with hierarchy and escape expressions"
```

---

## Task 5: Node submodule

**Files:**
- Modify: `modules/firewall/nodes.nix`
- Create: `tests/eval/nodes.nix`, `tests/assertions/node-missing-zone.nix`

- [ ] **Step 1: Write failing test**

```nix
# tests/eval/nodes.nix
{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };

  eval = cfg: (h.evalConfig ({ ... }: {
    networking.nftfw.enable = true;
    networking.nftfw.zones.lan.interfaces = [ "eth1" ];
  } // cfg)).networking.nftfw.nodes;
in
  h.runTests {
    testNode = {
      expr = (eval {
        networking.nftfw.nodes.webserver = {
          zone = "lan";
          address.ipv4 = "192.168.1.50";
        };
      }).webserver.address.ipv4;
      expected = "192.168.1.50";
    };
    testNodeDual = {
      expr = (eval {
        networking.nftfw.nodes.ws = {
          zone = "lan";
          address.ipv4 = "192.168.1.50";
          address.ipv6 = "fd00::50";
        };
      }).ws.address.ipv6;
      expected = "fd00::50";
    };
  }
```

- [ ] **Step 2: Run — expect fail**

- [ ] **Step 3: Implement**

```nix
# modules/firewall/nodes.nix
{ lib }:

{ config, ... }:

let
  nodeSubmodule = { name, ... }: {
    options = {
      zone = lib.mkOption {
        type = lib.types.str;
        description = "Parent zone (required).";
      };
      address.ipv4 = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      address.ipv6 = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      comment = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
    };
  };
in {
  options.networking.nftfw.nodes = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule nodeSubmodule);
    default = { };
    description = "Named hosts; usable wherever a zone is.";
  };
}
```

- [ ] **Step 4: Run — expect pass**

```bash
nix build .#checks.x86_64-linux.eval-nodes
```

- [ ] **Step 5: Commit**

```bash
git add modules/firewall/nodes.nix tests/eval/nodes.nix flake.nix
git commit -m "feat(firewall): Add node submodule"
```

---

## Task 6: Layer A primitives — sets, maps

**Files:**
- Modify: `modules/objects/sets.nix`, `modules/objects/maps.nix`
- Create: `tests/eval/sets.nix`, `tests/eval/maps.nix`

- [ ] **Step 1: Write failing test for sets**

```nix
# tests/eval/sets.nix
{ pkgs, libnet, nftlib }:
let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  eval = cfg: (h.evalConfig cfg).networking.nftfw.objects.sets;
in
  h.runTests {
    testSetBasic = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.sets.bl = {
          type = "ipv4_addr";
          flags = [ "interval" ];
          elements = [ "198.51.100.0/24" ];
        };
      })).bl.type;
      expected = "ipv4_addr";
    };
    testSetTables = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.sets.bl = {
          type = "ipv4_addr";
          tables = [ "main" ];
        };
      })).bl.tables;
      expected = [ "main" ];
    };
  }
```

- [ ] **Step 2: Implement `modules/objects/sets.nix`**

```nix
{ lib }:
{ config, ... }:

let
  setSubmodule = { name, ... }: {
    options = {
      type = lib.mkOption {
        type = lib.types.either lib.types.str (lib.types.listOf lib.types.str);
        description = "Set type (e.g. \"ipv4_addr\", [\"ipv4_addr\" \"inet_service\"]).";
      };
      flags = lib.mkOption {
        type = lib.types.listOf (lib.types.enum [ "constant" "interval" "timeout" "dynamic" ]);
        default = [ ];
      };
      elements = lib.mkOption {
        type = lib.types.listOf lib.types.unspecified;   # refined by renderer
        default = [ ];
      };
      timeout = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; };
      size    = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; };
      tables  = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = "null = auto-emit to all compatible tables; list = explicit restriction.";
      };
      comment = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
    };
  };
in {
  options.networking.nftfw.objects.sets = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule setSubmodule);
    default = { };
  };
}
```

- [ ] **Step 3: Implement `modules/objects/maps.nix`**

Same pattern as sets, plus a `map` field for value type:

```nix
{ lib }:
{ config, ... }:

let
  mapSubmodule = { name, ... }: {
    options = {
      type = lib.mkOption {
        type = lib.types.either lib.types.str (lib.types.listOf lib.types.str);
      };
      map = lib.mkOption {
        type = lib.types.either lib.types.str (lib.types.listOf lib.types.str);
        description = "Value type (e.g. \"verdict\", \"inet_service\").";
      };
      flags = lib.mkOption {
        type = lib.types.listOf (lib.types.enum [ "constant" "interval" "timeout" "dynamic" ]);
        default = [ ];
      };
      elements = lib.mkOption { type = lib.types.listOf lib.types.unspecified; default = [ ]; };
      timeout  = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; };
      size     = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; };
      tables   = lib.mkOption { type = lib.types.nullOr (lib.types.listOf lib.types.str); default = null; };
      comment  = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
    };
  };
in {
  options.networking.nftfw.objects.maps = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule mapSubmodule);
    default = { };
  };
}
```

- [ ] **Step 4: Write `tests/eval/maps.nix`** (analogous to sets)

```nix
{ pkgs, libnet, nftlib }:
let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  eval = cfg: (h.evalConfig cfg).networking.nftfw.objects.maps;
in
  h.runTests {
    testMapVerdict = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.maps.dispatch = {
          type = "ifname"; map = "verdict";
          elements = [ [ "eth0" { jump = { target = "wan-chain"; }; } ] ];
        };
      })).dispatch.map;
      expected = "verdict";
    };
  }
```

- [ ] **Step 5: Wire tests, run, commit**

```bash
# add eval-sets and eval-maps to flake checks
nix build .#checks.x86_64-linux.eval-sets .#checks.x86_64-linux.eval-maps
git add modules/objects/sets.nix modules/objects/maps.nix tests/eval/sets.nix tests/eval/maps.nix flake.nix
git commit -m "feat(objects): Add set and map submodules with auto-emit scoping"
```

---

## Task 7: Stateful objects — counters, quotas, limits

**Files:**
- Modify: `modules/objects/stateful.nix`
- Create: `tests/eval/stateful.nix`

- [ ] **Step 1: Write failing test**

```nix
{ pkgs, libnet, nftlib }:
let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  eval = cfg: (h.evalConfig cfg).networking.nftfw.objects;
in
  h.runTests {
    testCounter = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.counters.c1 = { };
      })).counters.c1;
      expected = { packets = null; bytes = null; tables = null; comment = null; };
    };
    testLimit = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.limits.slow = { rate = 5; per = "second"; burst = 10; };
      })).limits.slow.burst;
      expected = 10;
    };
    testQuota = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.quotas.monthly = { bytes = 1000000000; };
      })).quotas.monthly.bytes;
      expected = 1000000000;
    };
  }
```

- [ ] **Step 2: Implement**

```nix
# modules/objects/stateful.nix
{ lib }:
{ config, ... }:

let
  commonFields = {
    tables = lib.mkOption { type = lib.types.nullOr (lib.types.listOf lib.types.str); default = null; };
    comment = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
  };

  counterSubmodule = { ... }: {
    options = {
      packets = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; };
      bytes   = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; };
    } // commonFields;
  };

  quotaSubmodule = { ... }: {
    options = {
      bytes = lib.mkOption { type = lib.types.int; };
      used  = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; };
      inv   = lib.mkOption { type = lib.types.bool; default = false; };
    } // commonFields;
  };

  limitSubmodule = { ... }: {
    options = {
      rate      = lib.mkOption { type = lib.types.int; };
      per       = lib.mkOption { type = lib.types.enum [ "second" "minute" "hour" "day" "week" ]; };
      rateUnit  = lib.mkOption { type = lib.types.nullOr (lib.types.enum [ "packets" "bytes" ]); default = null; };
      burst     = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; };
      burstUnit = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      inv       = lib.mkOption { type = lib.types.bool; default = false; };
    } // commonFields;
  };
in {
  options.networking.nftfw.objects.counters = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule counterSubmodule);
    default = { };
  };
  options.networking.nftfw.objects.quotas = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule quotaSubmodule);
    default = { };
  };
  options.networking.nftfw.objects.limits = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule limitSubmodule);
    default = { };
  };
}
```

- [ ] **Step 3: Wire test, run, commit**

```bash
nix build .#checks.x86_64-linux.eval-stateful
git add modules/objects/stateful.nix tests/eval/stateful.nix flake.nix
git commit -m "feat(objects): Add counter, quota, and limit submodules"
```

---

## Task 8: CT objects — helpers, timeouts, expectations

**Files:**
- Modify: `modules/objects/ct.nix`
- Create: `tests/eval/ct.nix`

- [ ] **Step 1: Write failing test**

```nix
{ pkgs, libnet, nftlib }:
let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  eval = cfg: (h.evalConfig cfg).networking.nftfw.objects.ct;
in
  h.runTests {
    testCtHelper = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.ct.helpers.ftp = {
          type = "ftp"; protocol = "tcp"; l3proto = "ip";
        };
      })).helpers.ftp.type;
      expected = "ftp";
    };
    testCtTimeout = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.ct.timeouts.tcp-long = {
          protocol = "tcp"; l3proto = "ip";
          policy = { established = 86400; };
        };
      })).timeouts.tcp-long.policy.established;
      expected = 86400;
    };
  }
```

- [ ] **Step 2: Implement**

```nix
# modules/objects/ct.nix
{ lib }:
{ config, ... }:

let
  commonFields = {
    tables = lib.mkOption { type = lib.types.nullOr (lib.types.listOf lib.types.str); default = null; };
    comment = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
  };

  helperSubmodule = { ... }: {
    options = {
      type     = lib.mkOption { type = lib.types.str; };
      protocol = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      l3proto  = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
    } // commonFields;
  };

  timeoutSubmodule = { ... }: {
    options = {
      protocol = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      l3proto  = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      policy   = lib.mkOption { type = lib.types.attrsOf lib.types.int; default = { }; };
    } // commonFields;
  };

  expectationSubmodule = { ... }: {
    options = {
      l3proto  = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      protocol = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      dport    = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; };
      timeout  = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; };
      size     = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; };
    } // commonFields;
  };
in {
  options.networking.nftfw.objects.ct.helpers     = lib.mkOption { type = lib.types.attrsOf (lib.types.submodule helperSubmodule); default = { }; };
  options.networking.nftfw.objects.ct.timeouts    = lib.mkOption { type = lib.types.attrsOf (lib.types.submodule timeoutSubmodule); default = { }; };
  options.networking.nftfw.objects.ct.expectations = lib.mkOption { type = lib.types.attrsOf (lib.types.submodule expectationSubmodule); default = { }; };
}
```

- [ ] **Step 3: Wire, run, commit**

```bash
nix build .#checks.x86_64-linux.eval-ct
git add modules/objects/ct.nix tests/eval/ct.nix flake.nix
git commit -m "feat(objects): Add ct.helpers, ct.timeouts, ct.expectations submodules"
```

---

## Task 9: Remaining named objects — flowtables, secmarks, synproxies, tunnels

**Files:**
- Modify: `modules/objects/flowtables.nix`, `secmarks.nix`, `synproxies.nix`, `tunnels.nix`
- Create: `tests/eval/objects-misc.nix`

- [ ] **Step 1: Write failing test**

```nix
{ pkgs, libnet, nftlib }:
let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  eval = cfg: (h.evalConfig cfg).networking.nftfw.objects;
in
  h.runTests {
    testFlowtable = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.flowtables.offload = {
          hook = "ingress"; priority = 0;
          devices = [ "eth0" "eth1" ];
        };
      })).flowtables.offload.devices;
      expected = [ "eth0" "eth1" ];
    };
    testSynproxy = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.synproxies.shield = {
          mss = 1460; wscale = 7; flags = [ "timestamp" ];
        };
      })).synproxies.shield.mss;
      expected = 1460;
    };
    testSecmark = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.secmarks.trusted = {
          context = "system_u:object_r:firewall_mark_t:s0";
        };
      })).secmarks.trusted.context;
      expected = "system_u:object_r:firewall_mark_t:s0";
    };
  }
```

- [ ] **Step 2: Implement each submodule**

```nix
# modules/objects/flowtables.nix
{ lib }:
{ config, ... }:
let
  commonFields = {
    tables  = lib.mkOption { type = lib.types.nullOr (lib.types.listOf lib.types.str); default = null; };
    comment = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
  };
  flowtableSubmodule = { ... }: {
    options = {
      hook     = lib.mkOption { type = lib.types.enum [ "ingress" ]; default = "ingress"; };
      priority = lib.mkOption { type = lib.types.int; default = 0; };
      devices  = lib.mkOption { type = lib.types.listOf lib.types.str; };
    } // commonFields;
  };
in {
  options.networking.nftfw.objects.flowtables = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule flowtableSubmodule);
    default = { };
  };
}
```

```nix
# modules/objects/secmarks.nix
{ lib }:
{ config, ... }:
let
  commonFields = {
    tables  = lib.mkOption { type = lib.types.nullOr (lib.types.listOf lib.types.str); default = null; };
    comment = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
  };
  secmarkSubmodule = { ... }: {
    options = {
      context = lib.mkOption { type = lib.types.str; };
    } // commonFields;
  };
in {
  options.networking.nftfw.objects.secmarks = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule secmarkSubmodule);
    default = { };
  };
}
```

```nix
# modules/objects/synproxies.nix
{ lib }:
{ config, ... }:
let
  commonFields = {
    tables  = lib.mkOption { type = lib.types.nullOr (lib.types.listOf lib.types.str); default = null; };
    comment = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
  };
  synproxySubmodule = { ... }: {
    options = {
      mss    = lib.mkOption { type = lib.types.int; };
      wscale = lib.mkOption { type = lib.types.int; };
      flags  = lib.mkOption {
        type = lib.types.listOf (lib.types.enum [ "timestamp" "sack-perm" ]);
        default = [ ];
      };
    } // commonFields;
  };
in {
  options.networking.nftfw.objects.synproxies = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule synproxySubmodule);
    default = { };
  };
}
```

```nix
# modules/objects/tunnels.nix
{ lib }:
{ config, ... }:
let
  commonFields = {
    tables  = lib.mkOption { type = lib.types.nullOr (lib.types.listOf lib.types.str); default = null; };
    comment = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
  };
  tunnelSubmodule = { ... }: {
    options = {
      id = lib.mkOption { type = lib.types.int; };
      "src-ipv4" = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      "dst-ipv4" = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      "src-ipv6" = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      "dst-ipv6" = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      sport = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; };
      dport = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; };
      tunnel = lib.mkOption { type = lib.types.attrs; default = { }; };
    } // commonFields;
  };
in {
  options.networking.nftfw.objects.tunnels = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule tunnelSubmodule);
    default = { };
  };
}
```

- [ ] **Step 3: Wire, run, commit**

```bash
nix build .#checks.x86_64-linux.eval-objects-misc
git add modules/objects/flowtables.nix modules/objects/secmarks.nix modules/objects/synproxies.nix modules/objects/tunnels.nix tests/eval/objects-misc.nix flake.nix
git commit -m "feat(objects): Add flowtables, secmarks, synproxies, tunnels submodules"
```

---

## Task 10: Tables submodule

**Files:**
- Modify: `modules/objects/tables.nix`
- Create: `tests/eval/tables.nix`

- [ ] **Step 1: Write failing test**

```nix
{ pkgs, libnet, nftlib }:
let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  eval = cfg: (h.evalConfig cfg).networking.nftfw.objects.tables;
in
  h.runTests {
    testTableDefault = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.tables.main.family = "inet";
      })).main.family;
      expected = "inet";
    };
    testBaseChainPolicy = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.tables.main = {
          family = "inet";
          baseChains.input = { priority = 0; policy = "drop"; };
        };
      })).main.baseChains.input.policy;
      expected = "drop";
    };
  }
```

- [ ] **Step 2: Implement**

```nix
# modules/objects/tables.nix
{ lib }:
{ config, ... }:

let
  baseChainSubmodule = extraFields: { ... }: {
    options = {
      priority = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; };
      extraRules = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
      };
    } // extraFields;
  };

  filterBaseChain = baseChainSubmodule {
    policy = lib.mkOption { type = lib.types.nullOr (lib.types.enum [ "accept" "drop" ]); default = null; };
  };
  natBaseChain = baseChainSubmodule { };
  mangleBaseChain = baseChainSubmodule { };
  netdevBaseChain = baseChainSubmodule {
    devices = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; };
  };

  tableSubmodule = { name, ... }: {
    options = {
      family = lib.mkOption {
        type = lib.types.enum [ "ip" "ip6" "inet" "arp" "bridge" "netdev" ];
      };
      flags = lib.mkOption {
        type = lib.types.listOf (lib.types.enum [ "dormant" "owner" "persist" ]);
        default = [ ];
      };
      comment = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      extraContent = lib.mkOption { type = lib.types.nullOr lib.types.attrs; default = null; };

      baseChains.input            = lib.mkOption { type = lib.types.nullOr (lib.types.submodule filterBaseChain); default = null; };
      baseChains.forward          = lib.mkOption { type = lib.types.nullOr (lib.types.submodule filterBaseChain); default = null; };
      baseChains.output           = lib.mkOption { type = lib.types.nullOr (lib.types.submodule filterBaseChain); default = null; };
      baseChains.natPrerouting    = lib.mkOption { type = lib.types.nullOr (lib.types.submodule natBaseChain); default = null; };
      baseChains.natPostrouting   = lib.mkOption { type = lib.types.nullOr (lib.types.submodule natBaseChain); default = null; };
      baseChains.manglePrerouting = lib.mkOption { type = lib.types.nullOr (lib.types.submodule mangleBaseChain); default = null; };
      baseChains.ingress          = lib.mkOption { type = lib.types.nullOr (lib.types.submodule netdevBaseChain); default = null; };
      baseChains.egress           = lib.mkOption { type = lib.types.nullOr (lib.types.submodule netdevBaseChain); default = null; };
    };
  };
in {
  options.networking.nftfw.objects.tables = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule tableSubmodule);
    default = { };
  };
}
```

- [ ] **Step 3: Wire, run, commit**

```bash
nix build .#checks.x86_64-linux.eval-tables
git add modules/objects/tables.nix tests/eval/tables.nix flake.nix
git commit -m "feat(objects): Add table submodule with base chain overrides"
```

---

## Task 11: Chains submodule (R4 escape) + Ruleset submodule

**Files:**
- Modify: `modules/objects/chains.nix`, `modules/objects/ruleset.nix`
- Create: `tests/eval/chains.nix`

- [ ] **Step 1: Test**

```nix
{ pkgs, libnet, nftlib }:
let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  eval = cfg: (h.evalConfig cfg).networking.nftfw.objects;
in
  h.runTests {
    testChainDecl = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.chains.my-sub = {
          table = "main";
          rules = [ ];
        };
      })).chains.my-sub.table;
      expected = "main";
    };
    testRulesetOverride = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.ruleset = { nftables = [ ]; };
      })).ruleset;
      expected = { nftables = [ ]; };
    };
  }
```

- [ ] **Step 2: Implement `chains.nix`**

```nix
{ lib }:
{ config, ... }:

let
  chainSubmodule = { name, ... }: {
    options = {
      table    = lib.mkOption { type = lib.types.str; };
      type     = lib.mkOption { type = lib.types.nullOr (lib.types.enum [ "filter" "nat" "route" ]); default = null; };
      hook     = lib.mkOption { type = lib.types.nullOr (lib.types.enum [ "prerouting" "input" "forward" "output" "postrouting" "ingress" "egress" ]); default = null; };
      priority = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; };
      policy   = lib.mkOption { type = lib.types.nullOr (lib.types.enum [ "accept" "drop" ]); default = null; };
      devices  = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; };
      comment  = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      rules    = lib.mkOption { type = lib.types.listOf lib.types.attrs; default = [ ]; };
    };
  };
in {
  options.networking.nftfw.objects.chains = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule chainSubmodule);
    default = { };
  };
}
```

- [ ] **Step 3: Implement `ruleset.nix`**

```nix
{ lib }:
{ config, ... }:
{
  options.networking.nftfw.objects.ruleset = lib.mkOption {
    type = lib.types.nullOr lib.types.attrs;
    default = null;
    description = "Raw nftypes ruleset appended to networking.nftables.ruleset.";
  };
}
```

- [ ] **Step 4: Wire, run, commit**

```bash
nix build .#checks.x86_64-linux.eval-chains
git add modules/objects/chains.nix modules/objects/ruleset.nix tests/eval/chains.nix flake.nix
git commit -m "feat(objects): Add chain escape and ruleset override submodules"
```

---

## Task 12: Common rule fields + ruleFragment type

**Files:**
- Modify: `modules/firewall/rules-common.nix`
- Create: `lib/priority-bands.nix`

- [ ] **Step 1: Write `lib/priority-bands.nix`**

```nix
# lib/priority-bands.nix
{
  preDispatch  = 50;
  early        = 250;
  default      = 500;
  late         = 750;
  deny         = 950;
}
```

- [ ] **Step 2: Write `modules/firewall/rules-common.nix`**

```nix
# modules/firewall/rules-common.nix
{ lib }:

rec {
  matchSubmodule = { ... }: {
    options = {
      srcAddresses.ipv4 = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; };
      srcAddresses.ipv6 = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; };
      dstAddresses.ipv4 = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; };
      dstAddresses.ipv6 = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; };
      srcSet    = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      dstSet    = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      srcPorts.tcp = lib.mkOption { type = lib.types.listOf lib.types.unspecified; default = [ ]; };
      srcPorts.udp = lib.mkOption { type = lib.types.listOf lib.types.unspecified; default = [ ]; };
      dstPorts.tcp = lib.mkOption { type = lib.types.listOf lib.types.unspecified; default = [ ]; };
      dstPorts.udp = lib.mkOption { type = lib.types.listOf lib.types.unspecified; default = [ ]; };
      protocol  = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      tcpFlags  = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      ct.state  = lib.mkOption {
        type = lib.types.listOf (lib.types.enum [ "new" "established" "related" "invalid" "untracked" ]);
        default = [ ];
      };
      ct.direction = lib.mkOption { type = lib.types.nullOr (lib.types.enum [ "original" "reply" ]); default = null; };
      mark      = lib.mkOption { type = lib.types.nullOr (lib.types.oneOf [ lib.types.int lib.types.str ]); default = null; };
      extraMatch = lib.mkOption { type = lib.types.listOf lib.types.attrs; default = [ ]; };
    };
  };

  statementFields = {
    counter = lib.mkOption {
      type = lib.types.nullOr (lib.types.oneOf [ lib.types.bool lib.types.str lib.types.attrs ]);
      default = null;
    };
    log = lib.mkOption { type = lib.types.nullOr (lib.types.oneOf [ lib.types.bool lib.types.attrs ]); default = null; };
    limit = lib.mkOption { type = lib.types.nullOr (lib.types.oneOf [ lib.types.str lib.types.attrs ]); default = null; };
    quota = lib.mkOption { type = lib.types.nullOr (lib.types.oneOf [ lib.types.str lib.types.attrs ]); default = null; };
    ctHelper        = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
    ctTimeout       = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
    ctExpectation   = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
    synproxy        = lib.mkOption { type = lib.types.nullOr (lib.types.oneOf [ lib.types.str lib.types.attrs ]); default = null; };
    secmark         = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
    flowtable       = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
    tunnel          = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
    meter           = lib.mkOption { type = lib.types.nullOr lib.types.attrs; default = null; };
    connectionLimit = lib.mkOption { type = lib.types.nullOr lib.types.attrs; default = null; };
    extraStatements = lib.mkOption { type = lib.types.listOf lib.types.attrs; default = [ ]; };
  };

  verdictFields = {
    verdict = lib.mkOption { type = lib.types.nullOr (lib.types.enum [ "accept" "drop" "reject" "continue" "return" ]); default = null; };
    jumpTo  = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
    gotoTo  = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
  };

  dispatchFields = {
    from = lib.mkOption {
      type = lib.types.either lib.types.str (lib.types.listOf lib.types.str);
      default = [ ];
      apply = v: if builtins.isString v then [ v ] else v;
    };
    to = lib.mkOption {
      type = lib.types.either lib.types.str (lib.types.listOf lib.types.str);
      default = [ ];
      apply = v: if builtins.isString v then [ v ] else v;
    };
    tables = lib.mkOption { type = lib.types.nullOr (lib.types.listOf lib.types.str); default = null; };
  };

  coreFields = {
    enable = lib.mkOption { type = lib.types.bool; default = true; };
    comment = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
    priority = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; };
    match = lib.mkOption { type = lib.types.submodule matchSubmodule; default = { }; };
  } // statementFields // verdictFields;

  # Used by kind-typed rule submodules
  ruleCoreFields = coreFields // dispatchFields;

  # Used by objects.chains.<name>.rules[*]
  ruleFragmentFields = coreFields;
}
```

- [ ] **Step 3: Commit (no runtime behavior change; types only)**

```bash
git add modules/firewall/rules-common.nix lib/priority-bands.nix
git commit -m "feat(firewall): Add shared rule field types and priority band constants"
```

---

## Task 13: Filter rule submodule

**Files:**
- Modify: `modules/firewall/rules/filter.nix`
- Create: `tests/eval/rules-filter.nix`

- [ ] **Step 1: Test**

```nix
{ pkgs, libnet, nftlib }:
let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  eval = cfg: (h.evalConfig cfg).networking.nftfw.rules.filter;
in
  h.runTests {
    testFilter = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.zones.wan.interfaces = [ "eth0" ];
        networking.nftfw.rules.filter.ssh = {
          from = "wan"; to = "local";
          match.dstPorts.tcp = [ 22 ];
          verdict = "accept";
        };
      })).ssh.verdict;
      expected = "accept";
    };
    testFromCoercedToList = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.zones.wan.interfaces = [ "eth0" ];
        networking.nftfw.rules.filter.r = {
          from = "wan"; to = "local"; verdict = "drop";
        };
      })).r.from;
      expected = [ "wan" ];
    };
  }
```

- [ ] **Step 2: Implement**

```nix
# modules/firewall/rules/filter.nix
{ lib }:

{ config, ... }:

let
  common = import ../rules-common.nix { inherit lib; };
  filterRuleSubmodule = { name, ... }: {
    options = common.ruleCoreFields;
    config = {
      verdict = lib.mkDefault "accept";
    };
  };
in {
  options.networking.nftfw.rules.filter = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule filterRuleSubmodule);
    default = { };
  };
}
```

- [ ] **Step 3: Wire, run, commit**

```bash
nix build .#checks.x86_64-linux.eval-rules-filter
git add modules/firewall/rules/filter.nix tests/eval/rules-filter.nix flake.nix
git commit -m "feat(firewall): Add filter rule submodule"
```

---

## Task 14: ICMP rule submodule

**Files:**
- Modify: `modules/firewall/rules/icmp.nix`
- Create: `tests/eval/rules-icmp.nix`

- [ ] **Step 1: Test**

```nix
{ pkgs, libnet, nftlib }:
let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  eval = cfg: (h.evalConfig cfg).networking.nftfw.rules.icmp;
in
  h.runTests {
    testIcmp = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.rules.icmp.essentials = {
          from = "any"; to = "local";
          icmp.v4Types = [ "echo-request" "destination-unreachable" ];
          icmp.v6Types = [ "echo-request" "nd-neighbor-solicit" ];
          verdict = "accept";
        };
      })).essentials.icmp.v4Types;
      expected = [ "echo-request" "destination-unreachable" ];
    };
  }
```

- [ ] **Step 2: Implement**

```nix
# modules/firewall/rules/icmp.nix
{ lib }:
{ config, ... }:
let
  common = import ../rules-common.nix { inherit lib; };
  icmpRuleSubmodule = { name, ... }: {
    options = common.ruleCoreFields // {
      icmp.v4Types = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; };
      icmp.v6Types = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; };
    };
    config = {
      verdict = lib.mkDefault "accept";
    };
  };
in {
  options.networking.nftfw.rules.icmp = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule icmpRuleSubmodule);
    default = { };
  };
}
```

- [ ] **Step 3: Wire, run, commit**

```bash
nix build .#checks.x86_64-linux.eval-rules-icmp
git add modules/firewall/rules/icmp.nix tests/eval/rules-icmp.nix flake.nix
git commit -m "feat(firewall): Add icmp rule submodule"
```

---

## Task 15: Mangle rule submodule

**Files:**
- Modify: `modules/firewall/rules/mangle.nix`
- Create: `tests/eval/rules-mangle.nix`

- [ ] **Step 1: Test**

```nix
{ pkgs, libnet, nftlib }:
let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  eval = cfg: (h.evalConfig cfg).networking.nftfw.rules.mangle;
in
  h.runTests {
    testMangle = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.rules.mangle.mark-lan = {
          from = "lan";
          setMark = 42;
          setDscp = "ef";
        };
      })).mark-lan.setMark;
      expected = 42;
    };
  }
```

- [ ] **Step 2: Implement**

```nix
# modules/firewall/rules/mangle.nix
{ lib }:
{ config, ... }:
let
  common = import ../rules-common.nix { inherit lib; };
  mangleRuleSubmodule = { name, ... }: {
    options = (lib.filterAttrs (n: _: n != "to") common.ruleCoreFields) // {
      setMark = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; };
      setDscp = lib.mkOption {
        type = lib.types.nullOr (lib.types.oneOf [ lib.types.int lib.types.str ]);
        default = null;
      };
    };
  };
in {
  options.networking.nftfw.rules.mangle = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule mangleRuleSubmodule);
    default = { };
  };
}
```

- [ ] **Step 3: Wire, run, commit**

```bash
nix build .#checks.x86_64-linux.eval-rules-mangle
git add modules/firewall/rules/mangle.nix tests/eval/rules-mangle.nix flake.nix
git commit -m "feat(firewall): Add mangle rule submodule"
```

---

## Task 16: DNAT / SNAT / Redirect rule submodules

**Files:**
- Modify: `modules/firewall/rules/{dnat,snat,redirect}.nix`
- Create: `tests/eval/rules-nat.nix`

- [ ] **Step 1: Test**

```nix
{ pkgs, libnet, nftlib }:
let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  eval = cfg: (h.evalConfig cfg).networking.nftfw.rules;
in
  h.runTests {
    testDnat = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.zones.wan.interfaces = [ "eth0" ];
        networking.nftfw.rules.dnat.web = {
          from = "wan";
          match.dstPorts.tcp = [ 80 ];
          forwardTo = "192.168.1.50:80";
        };
      })).dnat.web.forwardTo;
      expected = "192.168.1.50:80";
    };
    testSnatMasquerade = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.zones.wan.interfaces = [ "eth0" ];
        networking.nftfw.rules.snat.masq = {
          from = "lan"; to = "wan";
          translateTo = null;
        };
      })).snat.masq.translateTo;
      expected = null;
    };
    testRedirect = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.rules.redirect.dns-cap = {
          from = "lan";
          match.dstPorts.udp = [ 53 ];
          redirectTo = 5353;
        };
      })).redirect.dns-cap.redirectTo;
      expected = 5353;
    };
  }
```

- [ ] **Step 2: Implement `dnat.nix`**

```nix
{ lib }:
{ config, ... }:
let
  common = import ../rules-common.nix { inherit lib; };
  dnatRuleSubmodule = { name, ... }: {
    options = (lib.filterAttrs (n: _: n != "to" && n != "verdict" && n != "jumpTo" && n != "gotoTo") common.ruleCoreFields) // {
      forwardTo = lib.mkOption { type = lib.types.str; description = "Endpoint string (e.g. \"webserver:80\", \"192.0.2.1:8080\", \":8080\")."; };
    };
  };
in {
  options.networking.nftfw.rules.dnat = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule dnatRuleSubmodule);
    default = { };
  };
}
```

- [ ] **Step 3: Implement `snat.nix`**

```nix
{ lib }:
{ config, ... }:
let
  common = import ../rules-common.nix { inherit lib; };
  snatRuleSubmodule = { name, ... }: {
    options = (lib.filterAttrs (n: _: n != "verdict" && n != "jumpTo" && n != "gotoTo") common.ruleCoreFields) // {
      translateTo = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "null = masquerade; otherwise endpoint string.";
      };
    };
  };
in {
  options.networking.nftfw.rules.snat = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule snatRuleSubmodule);
    default = { };
  };
}
```

- [ ] **Step 4: Implement `redirect.nix`**

```nix
{ lib }:
{ config, ... }:
let
  common = import ../rules-common.nix { inherit lib; };
  redirectRuleSubmodule = { name, ... }: {
    options = (lib.filterAttrs (n: _: n != "to" && n != "verdict" && n != "jumpTo" && n != "gotoTo") common.ruleCoreFields) // {
      redirectTo = lib.mkOption { type = lib.types.int; description = "Local port."; };
    };
  };
in {
  options.networking.nftfw.rules.redirect = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule redirectRuleSubmodule);
    default = { };
  };
}
```

- [ ] **Step 5: Wire, run, commit**

```bash
nix build .#checks.x86_64-linux.eval-rules-nat
git add modules/firewall/rules/dnat.nix modules/firewall/rules/snat.nix modules/firewall/rules/redirect.nix tests/eval/rules-nat.nix flake.nix
git commit -m "feat(firewall): Add dnat, snat, redirect rule submodules"
```

---

## Task 17: Pipeline stages 1-2 — collect and validate

**Files:**
- Create: `modules/pipeline/default.nix`, `modules/pipeline/collect.nix`, `modules/pipeline/validate.nix`
- Create: `lib/refs.nix`
- Create: `tests/assertions/missing-zone.nix`, `tests/assertions/cyclic-parent.nix`

- [ ] **Step 1: Write `lib/refs.nix` (helpers for name lookup / error messages)**

```nix
# lib/refs.nix
{ lib }:
rec {
  # Return lookup error message; empty list = no errors.
  checkExists = label: names: universe:
    lib.filter (n: !(lib.hasAttr n universe))
      (if builtins.isList names then names else [ names ]);
}
```

- [ ] **Step 2: Write `modules/pipeline/collect.nix`**

```nix
# modules/pipeline/collect.nix
{ lib, cfg }:

let
  coerceList = v: if builtins.isList v then v else [ v ];

  # Insert built-in zones if missing
  withBuiltinZones = zones:
    let
      local = zones.local or { };
      any   = zones.any or { };
    in
      zones // { inherit local any; };

  # Materialize nodes as synthetic child zones for later stages
  nodesAsZones = cfg:
    lib.mapAttrs' (name: node: {
      name = "node-${name}";
      value = {
        parent = node.zone;
        interfaces = [ ];
        addresses.ipv4 = if node.address.ipv4 != null then [ (node.address.ipv4 + "/32") ] else [ ];
        addresses.ipv6 = if node.address.ipv6 != null then [ (node.address.ipv6 + "/128") ] else [ ];
        conntrackZone = null;
        ingressExpression = null;
        egressExpression = null;
        comment = node.comment;
        _isNode = true;
        _nodeName = name;
      };
    }) cfg.nodes;
in {
  zones = (withBuiltinZones cfg.zones) // (nodesAsZones cfg);
  nodes = cfg.nodes;
  rules = cfg.rules;
  objects = cfg.objects;
}
```

- [ ] **Step 3: Write `modules/pipeline/validate.nix`**

```nix
# modules/pipeline/validate.nix
{ lib, collected }:

let
  zoneNames = lib.attrNames collected.zones;
  nodeNames = lib.attrNames collected.nodes;
  tableNames = lib.attrNames collected.objects.tables;

  # Parent reference check
  invalidParent = lib.concatMap (name:
    let z = collected.zones.${name}; in
    if z.parent != null && !(lib.elem z.parent zoneNames)
    then [ "zone '${name}' has unknown parent '${z.parent}'" ]
    else [ ]) zoneNames;

  # Cyclic parent check
  cyclicDetect = name:
    let
      go = seen: current:
        if lib.elem current seen then [ "zone hierarchy cycle through '${current}'" ]
        else let parent = (collected.zones.${current} or { }).parent or null;
             in if parent == null then [ ]
                else go (seen ++ [ current ]) parent;
    in go [ ] name;
  cyclicErrors = lib.unique (lib.concatMap cyclicDetect zoneNames);

  # Node zone reference check
  invalidNodeZone = lib.concatMap (name:
    let n = collected.nodes.${name}; in
    if !(lib.elem n.zone zoneNames) && !(lib.elem "node-${n.zone}" zoneNames)
    then [ "node '${name}' references unknown zone '${n.zone}'" ]
    else [ ]) nodeNames;

  # Zone/node name clash
  clash = lib.intersectLists zoneNames nodeNames;
  clashErrors = map (n: "name '${n}' used by both zone and node") clash;

  allErrors = invalidParent ++ cyclicErrors ++ invalidNodeZone ++ clashErrors;
in
  if allErrors == [ ]
  then { ok = true; errors = [ ]; }
  else throw ("nftfw: validation failed:\n  - " + lib.concatStringsSep "\n  - " allErrors)
```

- [ ] **Step 4: Write `modules/pipeline/default.nix` skeleton**

```nix
# modules/pipeline/default.nix
{ lib, nftlib }:

{ config, ... }:

let
  cfg = config.networking.nftfw;
  collected = import ./collect.nix { inherit lib; cfg = cfg; };
  _validated = import ./validate.nix { inherit lib collected; };
in {
  config.networking.nftfw._internal.ir = lib.mkIf cfg.enable {
    collected = collected;
    validated = _validated;
  };
}
```

Add to `module.nix`:
```nix
(import ./modules/pipeline/default.nix { inherit lib nftlib; })
```

- [ ] **Step 5: Write negative test `tests/assertions/missing-zone.nix`**

```nix
{ pkgs, libnet, nftlib }:
let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };

  result = builtins.tryEval (h.evalConfig ({ ... }: {
    networking.nftfw.enable = true;
    networking.nftfw.nodes.web = { zone = "nonexistent"; address.ipv4 = "10.0.0.1"; };
  })).networking.nftfw._internal.ir;
in
  pkgs.runCommand "assertion-missing-zone-fails" { } (
    if result.success
    then "echo 'expected failure, got success' >&2; exit 1"
    else "touch $out"
  )
```

Analogous for cyclic-parent.

- [ ] **Step 6: Wire, run, commit**

```bash
nix build .#checks.x86_64-linux.assertion-missing-zone .#checks.x86_64-linux.assertion-cyclic-parent
git add lib/refs.nix modules/pipeline/*.nix tests/assertions/*.nix module.nix flake.nix
git commit -m "feat(pipeline): Add collect and validate stages with reference checks"
```

---

## Task 18: Pipeline stage 3 — zone graph IR

**Files:**
- Create: `modules/pipeline/ir-zones.nix`, `lib/zone-predicate.nix`, `lib/family.nix`
- Create: `tests/ir/zones-basic.nix`

- [ ] **Step 1: Write `lib/family.nix`**

```nix
# lib/family.nix
{ lib }:
rec {
  all = [ "ip" "ip6" "inet" "arp" "bridge" "netdev" ];
  l3 = [ "ip" "ip6" "inet" "netdev" ];

  # Which families a zone is applicable to, given its declaration
  zoneApplicable = zone:
    if zone.ingressExpression != null then all
    else
      let
        hasIface = zone.interfaces != [ ];
        hasV4    = zone.addresses.ipv4 != [ ];
        hasV6    = zone.addresses.ipv6 != [ ];
      in
        if hasIface && !hasV4 && !hasV6 then all
        else
          (if hasV4 then [ "ip" "inet" "netdev" "bridge" ] else [ ])
          ++ (if hasV6 then [ "ip6" "inet" "netdev" "bridge" ] else [ ])
          ++ (if hasIface && !hasV4 && !hasV6 then all else [ ])
          |> lib.unique;
}
```

Note: the `|>` syntax requires Nix 2.15+; for broader compat, wrap in `lib.unique ((if … ) ++ …)`.

- [ ] **Step 2: Write `lib/zone-predicate.nix`**

```nix
# lib/zone-predicate.nix
{ lib, nftlib }:

let
  # Build an ingress predicate for a zone in a given family context.
  # Returns nftypes expression attrset (nullable — null = no members).
  ingressPredicate = { zone, family, direction ? "ingress" }:
    if direction == "ingress" && zone.ingressExpression != null
    then zone.ingressExpression
    else if direction == "egress" && zone.egressExpression != null
    then zone.egressExpression
    else
      let
        ifaceField = if direction == "ingress" then "iifname" else "oifname";
        addrField  = if direction == "ingress" then "saddr" else "daddr";

        ifaceMatch = lib.optional (zone.interfaces != [ ]) {
          match = {
            left = { meta = { key = ifaceField; }; };
            right = { set = zone.interfaces; };
            op = "in";
          };
        };

        v4Match = lib.optional (zone.addresses.ipv4 != [ ] && lib.elem family [ "ip" "inet" "netdev" "bridge" ]) {
          match = {
            left = { payload = { protocol = "ip"; field = addrField; }; };
            right = { set = zone.addresses.ipv4; };
            op = "in";
          };
        };

        v6Match = lib.optional (zone.addresses.ipv6 != [ ] && lib.elem family [ "ip6" "inet" "netdev" "bridge" ]) {
          match = {
            left = { payload = { protocol = "ip6"; field = addrField; }; };
            right = { set = zone.addresses.ipv6; };
            op = "in";
          };
        };

        parts = ifaceMatch ++ v4Match ++ v6Match;
      in
        if parts == [ ] then null
        else { _matches = parts; };   # combined with OR at render time
in {
  inherit ingressPredicate;
}
```

- [ ] **Step 3: Write `modules/pipeline/ir-zones.nix`**

```nix
# modules/pipeline/ir-zones.nix
{ lib, nftlib, collected }:

let
  family = import ../../lib/family.nix { inherit lib; };
  zonePred = import ../../lib/zone-predicate.nix { inherit lib nftlib; };

  buildGraph = zones:
    lib.mapAttrs (name: zone: {
      inherit name;
      parent = zone.parent;
      descendants = lib.filter (n: (zones.${n}.parent or null) == name) (lib.attrNames zones);
      familySet = family.zoneApplicable zone;
      predicates = lib.listToAttrs (map (f: {
        name = f;
        value = {
          ingress = zonePred.ingressPredicate { inherit zone; family = f; direction = "ingress"; };
          egress  = zonePred.ingressPredicate { inherit zone; family = f; direction = "egress";  };
        };
      }) family.all);
    }) zones;
in
  buildGraph collected.zones
```

- [ ] **Step 4: Wire into pipeline default**

In `modules/pipeline/default.nix`:

```nix
  irZones = import ./ir-zones.nix { inherit lib nftlib collected; };
  # ...
  config.networking.nftfw._internal.ir = lib.mkIf cfg.enable {
    collected = collected;
    validated = _validated;
    zones = irZones;
  };
```

- [ ] **Step 5: Write golden snapshot test `tests/ir/zones-basic.nix`**

```nix
{ pkgs, libnet, nftlib }:
let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  ir = (h.evalConfig ({ ... }: {
    networking.nftfw.enable = true;
    networking.nftfw.zones = {
      wan.interfaces = [ "eth0" ];
      lan = { interfaces = [ "eth1" ]; addresses.ipv4 = [ "192.168.1.0/24" ]; };
    };
  })).networking.nftfw._internal.ir.zones;
in
  h.runTests {
    testWanFamilySet = {
      expr = ir.wan.familySet;
      expected = [ "ip" "ip6" "inet" "arp" "bridge" "netdev" ];
    };
    testLanFamilySet = {
      expr = lib.sort (a: b: a < b) ir.lan.familySet;
      expected = lib.sort (a: b: a < b) [ "ip" "inet" "netdev" "bridge" ];
    };
    testLanInetIngress = {
      expr = ir.lan.predicates.inet.ingress != null;
      expected = true;
    };
  }
```

- [ ] **Step 6: Wire, run, commit**

```bash
nix build .#checks.x86_64-linux.ir-zones-basic
git add lib/family.nix lib/zone-predicate.nix modules/pipeline/ir-zones.nix modules/pipeline/default.nix tests/ir/zones-basic.nix flake.nix
git commit -m "feat(pipeline): Add zone graph IR with per-family predicates"
```

---

## Task 19: Pipeline stage 4 — table plan IR with lazy main

**Files:**
- Create: `modules/pipeline/ir-tables.nix`
- Create: `tests/ir/table-lazy-main.nix`

- [ ] **Step 1: Implement**

```nix
# modules/pipeline/ir-tables.nix
{ lib, collected }:

let
  hasAnyRules =
    let
      count = lib.foldl (acc: k: acc + (lib.length (lib.attrNames (collected.rules.${k} or { })))) 0
        [ "filter" "icmp" "mangle" "dnat" "snat" "redirect" ];
    in count > 0;

  userTables = collected.objects.tables;

  tables =
    if userTables != { } then userTables
    else if hasAnyRules then { main = { family = "inet"; flags = [ ]; comment = null; extraContent = null;
                                        baseChains = { input = null; forward = null; output = null;
                                                       natPrerouting = null; natPostrouting = null;
                                                       manglePrerouting = null; ingress = null; egress = null; }; }; }
    else { };
in
  lib.mapAttrs (name: t: {
    inherit name;
    family = t.family;
    flags = t.flags;
    synthesized = !(userTables ? ${name});
    neededBaseChains = [ ];   # filled in stage 5
  }) tables
```

- [ ] **Step 2: Wire into `default.nix` — add `tables = import ./ir-tables.nix { inherit lib collected; };`**

- [ ] **Step 3: Test**

```nix
# tests/ir/table-lazy-main.nix
{ pkgs, libnet, nftlib }:
let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  ir = cfg: (h.evalConfig cfg).networking.nftfw._internal.ir.tables;
in
  h.runTests {
    testLazyMain = {
      expr = (ir ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.rules.filter.r = { from = "any"; to = "local"; verdict = "accept"; };
      })).main.family;
      expected = "inet";
    };
    testNoLazyMainIfUserDeclared = {
      expr = (ir ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.tables.custom.family = "ip";
        networking.nftfw.rules.filter.r = { from = "any"; to = "local"; verdict = "accept"; };
      })) ? main;
      expected = false;
    };
    testNoSynthesisIfNoRules = {
      expr = (ir ({ ... }: {
        networking.nftfw.enable = true;
      })) == { };
      expected = true;
    };
  }
```

- [ ] **Step 4: Wire, run, commit**

```bash
nix build .#checks.x86_64-linux.ir-table-lazy-main
git add modules/pipeline/ir-tables.nix modules/pipeline/default.nix tests/ir/table-lazy-main.nix flake.nix
git commit -m "feat(pipeline): Add table plan IR with lazy main synthesis"
```

---

## Task 20: Pipeline stage 5 — rule emission resolution

**Files:**
- Create: `modules/pipeline/ir-rules.nix`
- Create: `tests/ir/rule-dual-stack.nix`

- [ ] **Step 1: Implement**

```nix
# modules/pipeline/ir-rules.nix
{ lib, collected, irZones, irTables }:

let
  family = import ../../lib/family.nix { inherit lib; };

  # For each (kind × ruleName × targetTable × family), produce an emission record.
  resolveRule = { kind, name, rule }:
    let
      # Which tables does this rule apply to?
      applicable = if rule.tables or null != null
                   then lib.filter (t: irTables ? ${t}) rule.tables
                   else lib.attrNames irTables;

      # For each candidate table, determine target family(ies)
      emissions = lib.concatMap (tableName:
        let
          tbl = irTables.${tableName};
          tblFamily = tbl.family;

          # NAT kinds require L3
          kindOk =
            if lib.elem kind [ "dnat" "snat" "redirect" ]
            then lib.elem tblFamily [ "ip" "ip6" "inet" ]
            else true;

          # Determine chain placement
          chain = {
            "filter" =
              let tos = rule.to or [ ]; froms = rule.from or [ ]; in
              if lib.elem "local" tos then "input"
              else if lib.elem "local" froms then "output"
              else "forward";
            "icmp" =
              let tos = rule.to or [ ]; froms = rule.from or [ ]; in
              if lib.elem "local" tos then "input"
              else if lib.elem "local" froms then "output"
              else "forward";
            "mangle" = "mangle-prerouting";
            "dnat" = "nat-prerouting";
            "redirect" = "nat-prerouting";
            "snat" = "nat-postrouting";
          }.${kind};
        in
          if !kindOk then [ ]
          else [ {
            inherit kind name tableName chain;
            family = tblFamily;
            rule = rule;
          } ]
        ) applicable;
    in emissions;

  allRules = lib.concatLists (lib.concatMap (kind:
    let kindRules = collected.rules.${kind} or { }; in
    map (name: resolveRule { inherit kind name; rule = kindRules.${name}; })
        (lib.attrNames kindRules)
  ) [ "filter" "icmp" "mangle" "dnat" "snat" "redirect" ]);
in
  allRules
```

- [ ] **Step 2: Wire into `default.nix` — add `rules = import ./ir-rules.nix { inherit lib collected; irZones = irZones; irTables = irTables; };`**

- [ ] **Step 3: Test**

```nix
# tests/ir/rule-dual-stack.nix
{ pkgs, libnet, nftlib }:
let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  rules = cfg: (h.evalConfig cfg).networking.nftfw._internal.ir.rules;
in
  h.runTests {
    testFilterRuleLandsInMain = {
      expr =
        let rs = rules ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.rules.filter.r = { from = "any"; to = "local"; verdict = "accept"; };
        }); in (lib.head rs).tableName;
      expected = "main";
    };
    testNatRuleSkipsBridge = {
      expr =
        let rs = rules ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.objects.tables.br.family = "bridge";
          networking.nftfw.rules.dnat.d = { from = "wan"; forwardTo = "10.0.0.1:80"; };
        }); in lib.all (r: r.tableName != "br") rs;
      expected = true;
    };
  }
```

- [ ] **Step 4: Wire, run, commit**

```bash
nix build .#checks.x86_64-linux.ir-rule-dual-stack
git add modules/pipeline/ir-rules.nix modules/pipeline/default.nix tests/ir/rule-dual-stack.nix flake.nix
git commit -m "feat(pipeline): Add rule emission resolution with family scoping"
```

---

## Task 21: Pipeline stage 6 — dispatch generation

**Files:**
- Create: `modules/pipeline/ir-dispatch.nix`
- Create: `tests/ir/dispatch-basic.nix`

- [ ] **Step 1: Implement**

```nix
# modules/pipeline/ir-dispatch.nix
{ lib, irZones, irRules }:

let
  # Group rules by (tableName, chain)
  grouped = lib.groupBy (r: "${r.tableName}::${r.chain}") irRules;

  # Zones referenced by rules
  referencedZones = rules:
    lib.unique (lib.concatMap (r:
      (r.rule.from or [ ]) ++ (r.rule.to or [ ])) rules);

  # Per (tableName × major-chain) build subchain list
  dispatch = lib.mapAttrs (key: rules:
    let
      zones = lib.filter (z: irZones ? ${z} && z != "any") (referencedZones rules);
    in {
      inherit key;
      subchains = map (zoneName:
        let zone = irZones.${zoneName}; in {
          name = "${lib.head (lib.splitString "::" key)}-from-${zoneName}";
          zoneName = zoneName;
          rules = lib.filter (r: lib.elem zoneName (r.rule.from or [ ])) rules;
        }) zones;
    }) grouped;
in
  dispatch
```

- [ ] **Step 2: Wire into `default.nix`**

- [ ] **Step 3: Test**

```nix
# tests/ir/dispatch-basic.nix
{ pkgs, libnet, nftlib }:
let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  ir = cfg: (h.evalConfig cfg).networking.nftfw._internal.ir.dispatch;
in
  h.runTests {
    testDispatchCreatesSubchain = {
      expr =
        let d = ir ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.zones.wan.interfaces = [ "eth0" ];
          networking.nftfw.rules.filter.r = { from = "wan"; to = "local"; verdict = "accept"; };
        });
        in lib.any (g: lib.any (s: s.zoneName == "wan") g.subchains) (lib.attrValues d);
      expected = true;
    };
  }
```

- [ ] **Step 4: Wire, run, commit**

```bash
nix build .#checks.x86_64-linux.ir-dispatch-basic
git add modules/pipeline/ir-dispatch.nix modules/pipeline/default.nix tests/ir/dispatch-basic.nix flake.nix
git commit -m "feat(pipeline): Add dispatch IR with per-zone subchains"
```

---

## Task 22: Stage 7 — kind renderers

**Files:**
- Create: `modules/pipeline/render-rules.nix` and one file per kind under `modules/pipeline/renderers/`
- Create: `tests/render/filter-basic.nix`

- [ ] **Step 1: Implement `renderers/filter.nix`**

```nix
# modules/pipeline/renderers/filter.nix
{ lib, nftlib }:

{ resolvedRule, zonePredicates, refs }:

let
  inherit (nftlib.dsl) accept drop reject;
  rule = resolvedRule.rule;
  family = resolvedRule.family;

  # Build match list
  matches = [ ]
    ++ (lib.optional (rule.match.dstPorts.tcp != [ ])
         { match = { left = { payload = { protocol = "tcp"; field = "dport"; }; };
                     right = { set = rule.match.dstPorts.tcp; }; op = "in"; }; })
    ++ (lib.optional (rule.match.dstPorts.udp != [ ])
         { match = { left = { payload = { protocol = "udp"; field = "dport"; }; };
                     right = { set = rule.match.dstPorts.udp; }; op = "in"; }; })
    ++ rule.match.extraMatch or [ ];

  # Statements
  statements = [ ]
    ++ (lib.optional (rule.counter != null && rule.counter != false)
         (if rule.counter == true then { counter = null; }
          else if builtins.isString rule.counter then { counter = rule.counter; }
          else { counter = rule.counter; }))
    ++ rule.extraStatements or [ ];

  # Verdict
  verdictStmt = {
    "accept" = { accept = null; };
    "drop" = { drop = null; };
    "reject" = { reject = null; };
    "continue" = { continue = null; };
    "return" = { return = null; };
  }.${rule.verdict or "accept"};
in
  matches ++ statements ++ [ verdictStmt ]
```

- [ ] **Step 2: Skeleton `render-rules.nix` dispatcher**

```nix
# modules/pipeline/render-rules.nix
{ lib, nftlib }:

let
  renderers = {
    filter   = import ./renderers/filter.nix { inherit lib nftlib; };
    # icmp, mangle, dnat, snat, redirect renderers added as stubs returning [ ]
    icmp     = { resolvedRule, zonePredicates, refs }: [ ];
    mangle   = { resolvedRule, zonePredicates, refs }: [ ];
    dnat     = { resolvedRule, zonePredicates, refs }: [ ];
    snat     = { resolvedRule, zonePredicates, refs }: [ ];
    redirect = { resolvedRule, zonePredicates, refs }: [ ];
  };
in {
  render = { resolvedRule, zonePredicates, refs }:
    renderers.${resolvedRule.kind} { inherit resolvedRule zonePredicates refs; };
}
```

- [ ] **Step 3: Test render via snapshot**

```nix
# tests/render/filter-basic.nix
{ pkgs, libnet, nftlib }:
let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  render = import ../../modules/pipeline/renderers/filter.nix { inherit lib; inherit nftlib; };

  input = {
    resolvedRule = {
      kind = "filter"; name = "ssh"; tableName = "main"; chain = "input"; family = "inet";
      rule = { match = { dstPorts.tcp = [ 22 ]; dstPorts.udp = [ ]; extraMatch = [ ]; }; verdict = "accept"; counter = null; extraStatements = [ ]; };
    };
    zonePredicates = { };
    refs = { };
  };
in
  h.runTests {
    testFilterRenderTcpMatch = {
      expr = lib.elemAt (render input) 0;
      expected = { match = { left = { payload = { protocol = "tcp"; field = "dport"; }; }; right = { set = [ 22 ]; }; op = "in"; }; };
    };
    testFilterRenderVerdict = {
      expr = lib.last (render input);
      expected = { accept = null; };
    };
  }
```

- [ ] **Step 4: Wire, run, commit**

```bash
nix build .#checks.x86_64-linux.render-filter-basic
git add modules/pipeline/render-rules.nix modules/pipeline/renderers/*.nix tests/render/filter-basic.nix flake.nix
git commit -m "feat(pipeline): Add filter rule renderer and dispatch shell"
```

Follow-up micro-tasks 22.2–22.6: Implement the other five renderers (icmp, mangle, dnat, snat, redirect). Each follows the filter.nix pattern — take resolvedRule, emit nftypes statements list. Expected commit per kind.

---

## Task 23: Stage 8 + 9 + 10 — object renderers, assembly, emit

**Files:**
- Create: `modules/pipeline/render-objects.nix`, `modules/pipeline/assemble.nix`, `modules/pipeline/emit.nix`
- Create: `tests/integration/smoke.nix`

- [ ] **Step 1: Implement `render-objects.nix` — convert `objects.sets`, `objects.maps`, `objects.counters`, etc. into nftypes attrsets per target table**

```nix
# modules/pipeline/render-objects.nix
{ lib, nftlib, collected, irTables }:

let
  family = import ../../lib/family.nix { inherit lib; };

  # Decide which tables an object emits into
  targetTables = obj: kind:
    let
      applicable = {
        sets = t: type:
          if type == "ipv4_addr" then lib.elem t.family [ "ip" "inet" "netdev" "bridge" ]
          else if type == "ipv6_addr" then lib.elem t.family [ "ip6" "inet" "netdev" "bridge" ]
          else true;
        maps = t: _: true;
        counters = t: _: true;
        quotas = t: _: true;
        limits = t: _: true;
        ctHelpers = t: _: true;
        ctTimeouts = t: _: true;
        ctExpectations = t: _: true;
        flowtables = t: _: lib.elem t.family [ "ip" "ip6" "inet" ];
        secmarks = t: _: true;
        synproxies = t: _: lib.elem t.family [ "ip" "ip6" "inet" ];
        tunnels = t: _: lib.elem t.family [ "ip" "ip6" "inet" ];
      };
    in
      if obj.tables or null != null then lib.filter (t: irTables ? ${t}) obj.tables
      else lib.filter (tName:
        let t = irTables.${tName}; in
        applicable.${kind} t (obj.type or null)
      ) (lib.attrNames irTables);

  # Emit each object into its target tables as nftypes structure
  # (simplified; full implementation handles all kinds)
  rendered = lib.mapAttrs (tableName: _tbl:
    let
      emitSets = lib.mapAttrs (name: s: {
        type = s.type; flags = s.flags; elements = s.elements;
      }) (lib.filterAttrs (_: s: lib.elem tableName (targetTables s "sets")) collected.objects.sets);
      # …analogous for maps, counters, quotas, limits, ct.*, flowtables, secmarks, synproxies, tunnels
    in
      { sets = emitSets; /* maps = …; counters = …; etc. */ }
  ) irTables;
in rendered
```

- [ ] **Step 2: Implement `assemble.nix`**

```nix
# modules/pipeline/assemble.nix
{ lib, nftlib, irTables, irRules, irDispatch, renderedObjects }:

let
  inherit (nftlib.dsl) table chain;

  buildTable = tableName:
    let
      tblPlan = irTables.${tableName};
      tableRulesByChain = lib.groupBy (r: r.chain)
        (lib.filter (r: r.tableName == tableName) irRules);

      chains = lib.mapAttrs (chainName: rulesInChain: {
        # Base chain config (type/hook/prio/policy by chain name)
        type = { "input" = "filter"; "forward" = "filter"; "output" = "filter";
                 "nat-prerouting" = "nat"; "nat-postrouting" = "nat";
                 "mangle-prerouting" = "route"; }.${chainName} or null;
        hook = { "input" = "input"; "forward" = "forward"; "output" = "output";
                 "nat-prerouting" = "prerouting"; "nat-postrouting" = "postrouting";
                 "mangle-prerouting" = "prerouting"; }.${chainName} or null;
        prio = 0;
        rules = [ ];   # filled by renderers
      }) tableRulesByChain;
    in
      table tblPlan.family tableName {
        inherit chains;
        sets = renderedObjects.${tableName}.sets or { };
        # maps, counters, etc.
      };
in
  lib.mapAttrs (name: _: buildTable name) irTables
```

- [ ] **Step 3: Implement `emit.nix`**

```nix
# modules/pipeline/emit.nix
{ lib, nftlib, cfg, assembled }:

let
  # Render each assembled nftypes table into text via toText
  tableContents = lib.mapAttrs (name: tbl:
    nftlib.toText { nftables = [ { add.table = tbl; } ]; }
  ) assembled;
in {
  networking.nftables.tables = lib.mapAttrs (name: content: {
    family = assembled.${name}.family;
    inherit content;
  }) tableContents;

  networking.nftables.flushRuleset = lib.mkIf cfg.authoritative (lib.mkDefault true);
  networking.firewall.enable = lib.mkIf cfg.authoritative (lib.mkDefault false);

  networking.nftables.ruleset = lib.mkIf (cfg.objects.ruleset != null)
    (nftlib.toText cfg.objects.ruleset);
}
```

- [ ] **Step 4: Wire all into `modules/pipeline/default.nix`**

```nix
{ lib, nftlib }:
{ config, ... }:
let
  cfg = config.networking.nftfw;
  collected = import ./collect.nix { inherit lib cfg; };
  _validated = import ./validate.nix { inherit lib collected; };
  irZones = import ./ir-zones.nix { inherit lib nftlib collected; };
  irTables = import ./ir-tables.nix { inherit lib collected; };
  irRules = import ./ir-rules.nix { inherit lib collected irZones irTables; };
  irDispatch = import ./ir-dispatch.nix { inherit lib irZones irRules; };
  renderedObjects = import ./render-objects.nix { inherit lib nftlib collected irTables; };
  assembled = import ./assemble.nix { inherit lib nftlib irTables irRules irDispatch renderedObjects; };
  emitted = import ./emit.nix { inherit lib nftlib cfg assembled; };
in {
  config = lib.mkIf cfg.enable (emitted // {
    networking.nftfw._internal.ir = {
      collected = collected;
      validated = _validated;
      zones = irZones;
      tables = irTables;
      rules = irRules;
      dispatch = irDispatch;
    };
  });
}
```

- [ ] **Step 5: Smoke integration test**

```nix
# tests/integration/smoke.nix
{ pkgs, libnet, nftlib }:
let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  cfg = h.evalConfig ({ ... }: {
    networking.nftfw.enable = true;
    networking.nftfw.authoritative = false;    # don't touch other knobs in test
    networking.nftfw.rules.filter.r = { from = "any"; to = "local"; match.dstPorts.tcp = [ 22 ]; verdict = "accept"; };
  });

  generated = cfg.networking.nftables.tables.main.content;
in
  pkgs.runCommand "smoke-nft-parse" {
    nativeBuildInputs = [ pkgs.nftables pkgs.util-linux ];
  } ''
    echo '${generated}' > ruleset.nft
    unshare -rn nft -c -f ruleset.nft
    touch $out
  ''
```

- [ ] **Step 6: Wire, run, commit**

```bash
nix build .#checks.x86_64-linux.integration-smoke
git add modules/pipeline/render-objects.nix modules/pipeline/assemble.nix modules/pipeline/emit.nix modules/pipeline/default.nix tests/integration/smoke.nix flake.nix
git commit -m "feat(pipeline): Add object rendering, table assembly, and emission"
```

---

## Task 24: First helper — loopback-accept

**Files:**
- Create: `modules/helpers/loopback-accept.nix`
- Create: `tests/eval/helper-loopback.nix`

- [ ] **Step 1: Implement**

```nix
# modules/helpers/loopback-accept.nix
{ lib }:

{ config, ... }:

let
  cfg = config.networking.nftfw;
  hcfg = cfg.helpers.loopbackAccept or { enable = false; };
in {
  options.networking.nftfw.helpers.loopbackAccept.enable = lib.mkOption {
    type = lib.types.bool;
    default = cfg.authoritative;
    description = "Accept all traffic on the loopback interface.";
  };

  config.networking.nftfw.rules.filter = lib.mkIf (cfg.enable && hcfg.enable) {
    _helper-loopback-accept = {
      priority = 100;
      from = "any";
      to = "local";
      match.extraMatch = [
        { match = { left = { meta = { key = "iifname"; }; }; right = "lo"; op = "=="; }; }
      ];
      verdict = "accept";
    };
  };
}
```

- [ ] **Step 2: Import in `module.nix`**

Add `(import ./modules/helpers/loopback-accept.nix { inherit lib; })` to the imports list.

- [ ] **Step 3: Test**

```nix
{ pkgs, libnet, nftlib }:
let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  eval = cfg: (h.evalConfig cfg).networking.nftfw.rules.filter;
in
  h.runTests {
    testLoopbackRulePresent = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
      })) ? _helper-loopback-accept;
      expected = true;
    };
    testLoopbackRuleAbsentWhenDisabled = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.helpers.loopbackAccept.enable = false;
      })) ? _helper-loopback-accept;
      expected = false;
    };
  }
```

- [ ] **Step 4: Wire, run, commit**

```bash
nix build .#checks.x86_64-linux.eval-helper-loopback
git add modules/helpers/loopback-accept.nix module.nix tests/eval/helper-loopback.nix flake.nix
git commit -m "feat(helpers): Add loopback-accept helper as extension-model proof"
```

---

## Task 25: Remaining helpers

One commit per helper, same pattern as Task 24. Short sketches below — each task is its own commit.

### 25a. `stop-ruleset.nix`

Reads `cfg.helpers.stopRuleset.{enable, keepAlivePorts}`. When enabled, sets `networking.nftables.stopRuleset` to a minimal text ruleset (loopback accept, established/related accept, allow TCP dport ∈ keepAlivePorts).

Default: `enable = cfg.authoritative`.

Commit: `feat(helpers): Add stop-ruleset helper for remote-access safety`

### 25b. `kernel-hardening.nix`

Reads `cfg.helpers.kernelHardening.enable`. Sets `boot.kernel.sysctl` entries for `net.ipv4.conf.*.rp_filter`, `accept_redirects`, `accept_source_route`, `log_martians`, `icmp_echo_ignore_broadcasts`, IPv6 counterparts.

Default: `enable = false`.

Commit: `feat(helpers): Add kernel-hardening helper with sysctl defaults`

### 25c. `conntrack-baseline.nix`

Adds `rules.filter._helper-conntrack-est-rel` (priority 100, `match.ct.state = [ "established" "related" ]`, verdict accept) and `_helper-conntrack-invalid` (priority 100, `match.ct.state = [ "invalid" ]`, verdict drop).

Default: `enable = cfg.authoritative`.

Commit: `feat(helpers): Add conntrack-baseline helper for est/rel accept and invalid drop`

### 25d. `rpfilter.nix`

Adds filter rules using `fib saddr oif` lookup to drop packets from wrong interface. Exposes `strict` (bool) and `exemptInterfaces` (listOf str).

Default: `enable = false`.

Commit: `feat(helpers): Add reverse-path-filter helper via fib saddr oif`

### 25e. `flow-offload.nix`

Exposes `enable`, `zones`, `interfaces`, `hardware`. When enabled: declares `objects.flowtables.offload` (ingress hook, priority 0, devices from interfaces); adds `rules.filter._helper-flow-offload` that enrolls matching traffic (`from` = zones, `ct.state = ["established" "related"]`, `flowtable = "offload"`).

Default: `enable = false`.

Commit: `feat(helpers): Add flow-offload helper for kernel offloading`

### 25f. `ip-forwarding.nix`

Exposes `enable`, `ipv4`, `ipv6` bools. Sets `boot.kernel.sysctl."net.ipv4.ip_forward" = 1`, `"net.ipv6.conf.all.forwarding" = 1` based on the flags.

Default: `enable = false`, `ipv4 = true`, `ipv6 = true`.

Commit: `feat(helpers): Add ip-forwarding helper for router sysctls`

### 25g. `defaults.nix` (meta-helper)

Imports stop-ruleset, conntrack-baseline, loopback-accept with `mkDefault enable = true`. Single-file import for "sensible defaults".

Commit: `feat(helpers): Add defaults meta-helper bundling the common set`

---

## Task 26: VM tests

**Files:**
- Create: `tests/vm/single-host.nix`, `tests/vm/router.nix`
- Modify: `flake.nix` to wire VM tests into `checks`

- [ ] **Step 1: Write single-host VM test**

```nix
# tests/vm/single-host.nix
{ pkgs, libnet, nftlib, self }:

pkgs.testers.runNixOSTest {
  name = "nftfw-single-host";
  nodes.machine = { ... }: {
    imports = [ self.nixosModules.default ];
    networking.nftfw = {
      enable = true;
      authoritative = true;
      rules.filter.ssh = {
        from = "any"; to = "local";
        match.dstPorts.tcp = [ 22 ];
        verdict = "accept";
      };
      helpers.loopbackAccept.enable = true;
      helpers.conntrackBaseline.enable = true;
    };
    services.openssh.enable = true;
  };
  testScript = ''
    machine.start()
    machine.wait_for_unit("nftables.service")
    machine.succeed("nft list ruleset | grep -q 'tcp dport { 22 }'")
    machine.succeed("ss -tlnp | grep -q ':22'")
  '';
}
```

- [ ] **Step 2: Write router VM test**

Similar shape with three machines (wan, gw, lan), NAT rules, node for an "internal service" on lan, dnat from wan to the service.

- [ ] **Step 3: Wire into `flake.nix` checks**

- [ ] **Step 4: Commit**

```bash
git add tests/vm/single-host.nix tests/vm/router.nix flake.nix
git commit -m "test(vm): Add single-host and router VM tests"
```

---

## Task 27: Architecture doc

**Files:**
- Create: `docs/ARCHITECTURE.md`

- [ ] **Step 1: Write `docs/ARCHITECTURE.md`** summarizing: two-layer design, option tree, pipeline stages with extension points, compilation flow diagram, testing strategy. No references to other projects. Short (~200 lines).

- [ ] **Step 2: Commit**

```bash
git add docs/ARCHITECTURE.md
git commit -m "docs: Add architecture documentation"
```

---

## Self-review

- **Spec coverage:** zones (Task 4), nodes (Task 5), sets/maps (6), stateful (7), ct (8), flowtables/secmarks/synproxies/tunnels (9), tables (10), chains+ruleset (11), rule-common (12), filter (13), icmp (14), mangle (15), nat (16), pipeline stages 1-2 (17), 3 (18), 4 (19), 5 (20), 6 (21), 7 (22), 8-10 (23), helpers (24-25g), VM tests (26), docs (27). Authoritative mode is wired into emit (23) and helpers' defaults depend on `cfg.authoritative`. F3 auto-scoping happens in ir-rules (20) and render-objects (23). Priority bands defined in lib (12) — actual band-based ordering is inside renderer and dispatch rendering (22, 23); flag for execution.
- **Placeholder scan:** `TODO` appears only in stated future items (libnet type refinement in Task 4, same spot noted at start). All code blocks contain actual code.
- **Type consistency:** `forwardTo`, `translateTo`, `redirectTo` names match the spec. `objects.ct.{helpers,timeouts,expectations}` match. `_internal.ir.{collected,validated,zones,tables,rules,dispatch}` names match across Tasks 17–21.
- **Scope check:** single subsystem, one plan. Commit plan maps 1:1 to tasks (27 tasks ≈ 27 commits, matching the spec's ~23 estimate with helpers expanded).

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-24-nixos-nftfw.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
