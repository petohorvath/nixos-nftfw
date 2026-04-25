# nixos-nftfw — Cleanup and nix-libnet Integration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to execute this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make nix-libnet earn its keep as a real dependency (catch invalid addresses, ports, endpoints at eval time), then close the gap between what the README claims and what's implemented (renderers, dispatch, validation).

**Architecture:** Five sequenced PRs. Earlier PRs are foundational and short; later PRs depend on earlier ones being merged.

**Tech Stack:** Same as the original plan — nixpkgs, nix-libnet, nix-nftypes, plus the existing test harness in `tests/harness.nix`.

**Reference docs:**
- Spec: `docs/specs/2026-04-24-nixos-nftfw-design.md` (moved from `docs/superpowers/specs/` in PR 0)
- Original implementation plan: `docs/plans/2026-04-24-nixos-nftfw.md`
- Holistic review (informal): findings from the 2026-04-25 code-quality + coverage agents — summarised as PRs 3-5 below

---

## PR 0 — Repo housekeeping (1 commit, ~10 min)

Move the spec out of the `docs/superpowers/` namespace.

### Task 0.1: Move spec file and update references

**Files:**
- Move: `docs/superpowers/specs/2026-04-24-nixos-nftfw-design.md` → `docs/specs/2026-04-24-nixos-nftfw-design.md`
- Remove empty `docs/superpowers/` directory tree
- Modify: `README.md` — update path reference
- Modify: `docs/ARCHITECTURE.md` — update path reference
- Modify: `docs/plans/2026-04-24-nixos-nftfw.md` — update internal reference if any

- [ ] **Step 1: Move the file**

```bash
mkdir -p docs/specs
git mv docs/superpowers/specs/2026-04-24-nixos-nftfw-design.md docs/specs/
rmdir docs/superpowers/specs docs/superpowers
```

- [ ] **Step 2: Update references via grep and edit**

```bash
grep -rln "docs/superpowers/specs" --include="*.md" --include="*.nix"
```

For each match, change `docs/superpowers/specs/2026-04-24-nixos-nftfw-design.md` to `docs/specs/2026-04-24-nixos-nftfw-design.md`.

- [ ] **Step 3: Verify nothing else references the old path**

```bash
grep -rln "superpowers/specs" .
# expect: no matches (or only this very plan file)
```

- [ ] **Step 4: Commit**

```bash
git add -A docs/ README.md
git commit -m "docs: Move spec from docs/superpowers/specs to docs/specs"
```

---

## PR 1 — nix-libnet integration

This is the centrepiece. After this PR, every option that takes a network value (IP, CIDR, port, endpoint, interface name) is typed against the corresponding nix-libnet type, so malformed input fails at NixOS evaluation time with a clear message instead of silently propagating to `nft -f`.

### Background — what nix-libnet provides

From the original spec analysis:

- `libnet.types.ipv4` — single IPv4 address; coerces from string
- `libnet.types.ipv6` — single IPv6 address (RFC 5952 canonical form)
- `libnet.types.ip` — either v4 or v6
- `libnet.types.cidr`, `ipv4Cidr`, `ipv6Cidr` — CIDR block
- `libnet.types.port` — integer in 0..65535, classification helpers
- `libnet.types.portRange` — inclusive port range (string `"a-b"`)
- `libnet.types.endpoint` — addr:port string (RFC 3986 bracketing)
- `libnet.types.listener` — addr:portrange or wildcard `*:PORT`
- `libnet.types.mac` — EUI-48 MAC address
- `libnet.types.interface`, `ipv4Interface`, `ipv6Interface` — addr/prefix
- `libnet.types.ipRange` — non-CIDR `from-to` range

These are exposed when `libnet.withLib pkgs.lib` is invoked. The flake input (`nix-libnet`) is already declared but the threading was lost during Task 26's emit.nix rework.

### Task 1.1: Wire libnet into module.nix and harness

Re-establish the `libnet` arg path from flake → module → submodules → tests.

**Files:**
- Modify: `flake.nix` — pass `libnet = nix-libnet.lib;` to module.nix
- Modify: `module.nix` — accept `libnet` arg, attach it as a `_module.args` value so submodules can take `{ libnet, ... }:`
- Modify: `tests/harness.nix` — same wiring

- [ ] **Step 1: Update flake.nix**

Change the `nixosModules.default` line to:

```nix
nixosModules.default = import ./module.nix {
  lib = nixpkgs.lib;
  nftlib = nix-nftypes.lib;
  libnet = nix-libnet.lib;
};
```

- [ ] **Step 2: Update module.nix**

```nix
{ lib, nftlib, libnet }:

{ config, ... }:

let
  libnetTyped = libnet.withLib lib;
in {
  _module.args.libnet = libnetTyped;
  _module.args.nftlib = nftlib;

  imports = [
    (import ./modules/options.nix { inherit lib; })
    # ... rest unchanged for now ...
  ];
}
```

After this, any submodule can access libnet types via `{ config, libnet, ... }:` in the inner function.

- [ ] **Step 3: Update tests/harness.nix**

The harness already passes `libnet` as a function argument. Make sure it forwards through `_module.args` like `module.nix` does.

```nix
{ pkgs, libnet, nftlib }:

let
  inherit (pkgs) lib;

  evalConfig = userConfig: (lib.evalModules {
    modules = [
      (import ../module.nix { inherit lib nftlib libnet; })
      userConfig
    ];
  }).config;

  # ... runTests unchanged ...
```

(Note: with `_module.args` set inside `module.nix`, `specialArgs` is no longer needed.)

- [ ] **Step 4: Verify all existing checks still pass**

```bash
nix flake check --no-build 2>&1 | tail -3
```

- [ ] **Step 5: Commit**

```bash
git add flake.nix module.nix tests/harness.nix
git commit -m "feat(libnet): Thread nix-libnet types through the module system"
```

### Task 1.2: Update zone address types

**Files:**
- Modify: `modules/firewall/zones.nix` — `addresses.ipv4`/`.ipv6` use libnet types
- Modify: `tests/eval/zones.nix` — adjust if needed (existing valid CIDRs should still pass)
- Create: `tests/assertions/zone-bad-ipv4.nix` — negative test for malformed CIDR

- [ ] **Step 1: Refactor zones.nix to take libnet via module-arg**

```nix
{ lib }:

{ config, libnet, ... }:

let
  zoneSubmodule = { name, ... }: {
    options = {
      # ... parent, interfaces unchanged ...

      addresses.ipv4 = lib.mkOption {
        type = lib.types.listOf libnet.types.ipv4Cidr;
        default = [ ];
        description = "IPv4 addresses or CIDR blocks that belong to this zone.";
      };
      addresses.ipv6 = lib.mkOption {
        type = lib.types.listOf libnet.types.ipv6Cidr;
        default = [ ];
        description = "IPv6 addresses or CIDR blocks that belong to this zone.";
      };

      # ... rest unchanged ...
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
    any = lib.mkDefault { };
  };
}
```

- [ ] **Step 2: Verify existing zones tests still pass**

```bash
nix build .#checks.x86_64-linux.eval-zones 2>&1 | tail -3
```

If a test config used a malformed CIDR string that previously evaluated, it now fails — that's correct behavior; fix the test to use a valid CIDR.

- [ ] **Step 3: Add negative assertion test**

```nix
# tests/assertions/zone-bad-ipv4.nix
{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };

  result = builtins.tryEval (
    builtins.deepSeq
      (h.evalConfig ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.zones.bad.addresses.ipv4 = [ "999.0.0.1/24" ];
      })).networking.nftfw.zones
      "ok"
  );
in
  pkgs.runCommand "assertion-zone-bad-ipv4-fails" { } (
    if result.success
    then ''
      echo 'expected eval failure (libnet should reject 999.0.0.1/24) but got success' >&2
      exit 1
    ''
    else "touch $out"
  )
```

Wire `assertion-zone-bad-ipv4 = mkTest ./tests/assertions/zone-bad-ipv4.nix;` in `flake.nix`.

- [ ] **Step 4: Verify negative test fails for the right reason**

```bash
nix build .#checks.x86_64-linux.assertion-zone-bad-ipv4 2>&1 | tail -3
```

- [ ] **Step 5: Commit**

```bash
git add modules/firewall/zones.nix tests/eval/zones.nix tests/assertions/zone-bad-ipv4.nix flake.nix
git commit -m "feat(libnet): Validate zone address fields with libnet ipv4Cidr/ipv6Cidr"
```

### Task 1.3: Update node address types

**Files:**
- Modify: `modules/firewall/nodes.nix` — `address.ipv4`/`.ipv6` use libnet types
- Create: `tests/assertions/node-bad-address.nix`

- [ ] **Step 1: Refactor nodes.nix**

```nix
{ lib }:

{ config, libnet, ... }:

let
  nodeSubmodule = { name, ... }: {
    options = {
      zone = lib.mkOption {
        type = lib.types.str;
        description = "Parent zone (required). The node materialises as a synthetic child zone at /32 or /128.";
      };
      address.ipv4 = lib.mkOption {
        type = lib.types.nullOr libnet.types.ipv4;
        default = null;
        description = "Single IPv4 address for this node.";
      };
      address.ipv6 = lib.mkOption {
        type = lib.types.nullOr libnet.types.ipv6;
        default = null;
        description = "Single IPv6 address for this node.";
      };
      comment = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Free-form comment carried into the generated ruleset.";
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

- [ ] **Step 2: Add negative assertion test (analogous to Task 1.2 Step 3)**

```nix
# tests/assertions/node-bad-address.nix
{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };

  result = builtins.tryEval (
    builtins.deepSeq
      (h.evalConfig ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.zones.lan.interfaces = [ "eth1" ];
        networking.nftfw.nodes.bad = {
          zone = "lan";
          address.ipv4 = "not-an-ip";
        };
      })).networking.nftfw.nodes
      "ok"
  );
in
  pkgs.runCommand "assertion-node-bad-address-fails" { } (
    if result.success
    then ''
      echo 'expected eval failure (libnet should reject "not-an-ip") but got success' >&2
      exit 1
    ''
    else "touch $out"
  )
```

Wire `assertion-node-bad-address` in flake.nix.

- [ ] **Step 3: Build, commit**

```bash
nix build .#checks.x86_64-linux.eval-nodes .#checks.x86_64-linux.assertion-node-bad-address 2>&1 | tail -5
git add modules/firewall/nodes.nix tests/assertions/node-bad-address.nix flake.nix
git commit -m "feat(libnet): Validate node address fields with libnet ipv4/ipv6"
```

### Task 1.4: Update rule match address/port types

**Files:**
- Modify: `modules/firewall/rules-common.nix` — `srcAddresses`/`dstAddresses` use ipv4Cidr/ipv6Cidr; `srcPorts`/`dstPorts` use port-or-portRange
- Modify: each rule kind submodule that takes `{ lib }:` only — they import rules-common via `import ../rules-common.nix { inherit lib; }`. Rules-common needs libnet now, so each kind module needs to pass libnet through.

The cleanest pattern: `rules-common.nix` returns a function that takes libnet and returns the field groups. Then each kind module passes libnet from its own module-arg context.

- [ ] **Step 1: Refactor rules-common.nix to accept libnet**

```nix
# modules/firewall/rules-common.nix
{ lib, libnet }:

rec {
  matchSubmodule = { ... }: {
    options = {
      srcAddresses.ipv4 = lib.mkOption {
        type = lib.types.listOf libnet.types.ipv4Cidr;
        default = [ ];
        description = "IPv4 source addresses or CIDR blocks to match.";
      };
      srcAddresses.ipv6 = lib.mkOption {
        type = lib.types.listOf libnet.types.ipv6Cidr;
        default = [ ];
        description = "IPv6 source addresses or CIDR blocks to match.";
      };
      dstAddresses.ipv4 = lib.mkOption {
        type = lib.types.listOf libnet.types.ipv4Cidr;
        default = [ ];
        description = "IPv4 destination addresses or CIDR blocks to match.";
      };
      dstAddresses.ipv6 = lib.mkOption {
        type = lib.types.listOf libnet.types.ipv6Cidr;
        default = [ ];
        description = "IPv6 destination addresses or CIDR blocks to match.";
      };
      # srcSet / dstSet stay as nullOr str (they are name references)
      srcSet = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Name of an `objects.sets.<name>` to match against the source address.";
      };
      dstSet = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Name of an `objects.sets.<name>` to match against the destination address.";
      };
      srcPorts.tcp = lib.mkOption {
        type = lib.types.listOf (lib.types.either libnet.types.port libnet.types.portRange);
        default = [ ];
        description = "TCP source ports or port ranges to match.";
      };
      srcPorts.udp = lib.mkOption {
        type = lib.types.listOf (lib.types.either libnet.types.port libnet.types.portRange);
        default = [ ];
        description = "UDP source ports or port ranges to match.";
      };
      dstPorts.tcp = lib.mkOption {
        type = lib.types.listOf (lib.types.either libnet.types.port libnet.types.portRange);
        default = [ ];
        description = "TCP destination ports or port ranges to match.";
      };
      dstPorts.udp = lib.mkOption {
        type = lib.types.listOf (lib.types.either libnet.types.port libnet.types.portRange);
        default = [ ];
        description = "UDP destination ports or port ranges to match.";
      };
      # ... protocol, tcpFlags, ct.*, mark, extraMatch unchanged ...
    };
  };

  # ... statementFields, verdictFields, dispatchFields unchanged ...
  # coreFields, ruleCoreFields, ruleFragmentFields unchanged ...
}
```

- [ ] **Step 2: Update each rule kind submodule to pass libnet to rules-common**

For example `modules/firewall/rules/filter.nix`:

```nix
{ lib }:

{ config, libnet, ... }:

let
  common = import ../rules-common.nix { inherit lib libnet; };

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
    description = ''
      Kind-typed filter rules. Each entry is dispatched into input,
      forward, or output chains based on (from, to) zones; "local"
      acts as a marker for the host itself. Default verdict is accept.
    '';
  };
}
```

Apply the same pattern to icmp.nix, mangle.nix, dnat.nix, snat.nix, redirect.nix.

- [ ] **Step 3: Update existing rule tests to use valid values**

Most existing tests use literal valid IPs/ports/CIDRs and should still pass. Run all rule eval tests and fix any that broke.

- [ ] **Step 4: Add negative assertion test for malformed match port**

```nix
# tests/assertions/rule-bad-port.nix
{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };

  result = builtins.tryEval (
    builtins.deepSeq
      (h.evalConfig ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.rules.filter.r = {
          from = "any"; to = "local";
          match.dstPorts.tcp = [ 99999 ];   # > 65535
          verdict = "accept";
        };
      })).networking.nftfw.rules.filter
      "ok"
  );
in
  pkgs.runCommand "assertion-rule-bad-port-fails" { } (
    if result.success
    then ''
      echo 'expected eval failure (libnet should reject port 99999) but got success' >&2
      exit 1
    ''
    else "touch $out"
  )
```

Wire `assertion-rule-bad-port` in flake.nix.

- [ ] **Step 5: Commit**

```bash
git add modules/firewall/rules-common.nix \
        modules/firewall/rules/{filter,icmp,mangle,dnat,snat,redirect}.nix \
        tests/eval/rules-*.nix \
        tests/assertions/rule-bad-port.nix \
        flake.nix
git commit -m "feat(libnet): Validate rule match address/port fields with libnet types"
```

### Task 1.5: Update NAT rule endpoint targets

**Files:**
- Modify: `modules/firewall/rules/dnat.nix` — `forwardTo` uses libnet endpoint
- Modify: `modules/firewall/rules/snat.nix` — `translateTo` uses nullOr endpoint
- Modify: `modules/firewall/rules/redirect.nix` — `redirectTo` uses libnet port
- Update: `tests/eval/rules-nat.nix` — confirm passes

The challenge for dnat/snat: `forwardTo = "webserver:80"` (node-name reference) is NOT a valid libnet endpoint — it has a name where libnet expects an IP. Two approaches:

a) **Stay with `lib.types.str`** for forwardTo/translateTo and validate at the renderer when resolving the node reference. (Less type-safety, easier.)

b) **Use a coercion type** that accepts either a libnet endpoint OR a `<nodename>:<port>` string. Implement as `lib.types.either libnet.types.endpoint <node-ref-string-type>`.

Recommendation: **(a)** for this PR — keep the field as `str`, document that node-name forms are accepted, and add the libnet-typed validation only after node-reference resolution lands in the renderer (which is PR 4 territory). Note this in TODO.md.

- [ ] **Step 1: Update redirect.nix to use libnet.types.port for redirectTo**

```nix
# modules/firewall/rules/redirect.nix
{ lib }:

{ config, libnet, ... }:

let
  common = import ../rules-common.nix { inherit lib libnet; };

  baseFields = lib.filterAttrs
    (n: _: !(builtins.elem n [ "to" "verdict" "jumpTo" "gotoTo" ]))
    common.ruleCoreFields;

  redirectRuleSubmodule = { name, ... }: {
    options = baseFields // {
      redirectTo = lib.mkOption {
        type = libnet.types.port;
        description = "Local port to redirect matching traffic to (transparent proxy).";
      };
    };
  };
in {
  options.networking.nftfw.rules.redirect = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule redirectRuleSubmodule);
    default = { };
    description = ''
      Kind-typed redirect rules. Run in nat-prerouting; rewrite the
      destination to a local port (used for transparent proxies).
    '';
  };
}
```

- [ ] **Step 2: dnat.nix and snat.nix stay with str-typed targets, but add a TODO comment**

```nix
# In dnat.nix forwardTo description, add:
#   "Validation against libnet.types.endpoint is deferred until node-name
#    resolution lands in the renderer; today the field is `str`."
```

- [ ] **Step 3: Add negative test for redirect bad port**

```nix
# tests/assertions/redirect-bad-port.nix
{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  result = builtins.tryEval (
    builtins.deepSeq
      (h.evalConfig ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.rules.redirect.r = {
          from = "any";
          redirectTo = -5;   # libnet rejects
        };
      })).networking.nftfw.rules.redirect
      "ok"
  );
in
  pkgs.runCommand "assertion-redirect-bad-port-fails" { } (
    if result.success
    then "exit 1" else "touch $out"
  )
```

- [ ] **Step 4: Build all rule tests, commit**

```bash
nix build .#checks.x86_64-linux.eval-rules-nat .#checks.x86_64-linux.assertion-redirect-bad-port 2>&1 | tail -5
git add modules/firewall/rules/{dnat,snat,redirect}.nix tests/assertions/redirect-bad-port.nix flake.nix
git commit -m "feat(libnet): Validate redirect target port with libnet.types.port"
```

### Task 1.6: Update tunnel address fields

**Files:**
- Modify: `modules/objects/tunnels.nix` — `src-ipv4`/`dst-ipv4`/`src-ipv6`/`dst-ipv6` use libnet types; `sport`/`dport` use libnet port

- [ ] **Step 1: Refactor tunnels.nix**

```nix
{ lib }:

{ config, libnet, ... }:

let
  inherit (import ./_common.nix { inherit lib; }) commonFields;

  tunnelSubmodule = { name, ... }: {
    options = {
      id = lib.mkOption {
        type = lib.types.int;
        description = "Tunnel id (VXLAN VNI, ERSPAN id, GENEVE VNI).";
      };
      "src-ipv4" = lib.mkOption {
        type = lib.types.nullOr libnet.types.ipv4;
        default = null;
        description = "IPv4 source endpoint for the tunnel.";
      };
      "dst-ipv4" = lib.mkOption {
        type = lib.types.nullOr libnet.types.ipv4;
        default = null;
        description = "IPv4 destination endpoint.";
      };
      "src-ipv6" = lib.mkOption {
        type = lib.types.nullOr libnet.types.ipv6;
        default = null;
        description = "IPv6 source endpoint.";
      };
      "dst-ipv6" = lib.mkOption {
        type = lib.types.nullOr libnet.types.ipv6;
        default = null;
        description = "IPv6 destination endpoint.";
      };
      sport = lib.mkOption {
        type = lib.types.nullOr libnet.types.port;
        default = null;
        description = "Encapsulating transport source port.";
      };
      dport = lib.mkOption {
        type = lib.types.nullOr libnet.types.port;
        default = null;
        description = "Encapsulating transport destination port.";
      };
      tunnel = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Tunnel-type-specific fields (vxlan/erspan-v1/erspan-v2/geneve sub-record).";
      };
    } // commonFields;
  };
in {
  options.networking.nftfw.objects.tunnels = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule tunnelSubmodule);
    default = { };
    description = "Named tunnel objects (VXLAN, ERSPAN, GENEVE).";
  };
}
```

- [ ] **Step 2: Existing eval-objects-misc test should still pass with valid IPs**

```bash
nix build .#checks.x86_64-linux.eval-objects-misc 2>&1 | tail -3
```

- [ ] **Step 3: Commit**

```bash
git add modules/objects/tunnels.nix
git commit -m "feat(libnet): Validate tunnel address and port fields with libnet types"
```

### Task 1.7: Update helper port lists

**Files:**
- Modify: `modules/helpers/stop-ruleset.nix` — `keepAlivePorts` uses libnet port

- [ ] **Step 1: Refactor stop-ruleset.nix**

```nix
{ lib }:

{ config, libnet, ... }:

let
  cfg = config.networking.nftfw;
  hcfg = cfg.helpers.stopRuleset;
  # ... sshPorts, portList, rulesetText unchanged ...
in {
  options.networking.nftfw.helpers.stopRuleset = {
    enable = lib.mkOption { ... };   # unchanged
    keepAlivePorts = lib.mkOption {
      type = lib.types.listOf libnet.types.port;
      default = sshPorts;
      defaultText = lib.literalExpression ''
        if config.services.openssh.enable
        then config.services.openssh.ports or [ 22 ]
        else [ ]
      '';
      description = ''
        TCP destination ports to accept while the stop ruleset is in
        effect. Defaults to the configured OpenSSH ports (or [22] if
        OpenSSH is enabled but no port list is set), or [] if OpenSSH
        is disabled.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && hcfg.enable) {
    networking.nftables.stopRuleset = lib.mkDefault rulesetText;
  };
}
```

- [ ] **Step 2: Verify tests, commit**

```bash
nix build .#checks.x86_64-linux.eval-helper-stop-ruleset 2>&1 | tail -3
git add modules/helpers/stop-ruleset.nix
git commit -m "feat(libnet): Validate stop-ruleset keepAlivePorts with libnet port type"
```

### Task 1.8: Document the libnet integration in ARCHITECTURE.md and README

**Files:**
- Modify: `docs/ARCHITECTURE.md` — add a section explaining the libnet integration: which fields are validated, where the boundary is between libnet-typed and free-form (string-typed by-name references)
- Modify: `README.md` — add a "Validation" section listing what fails at eval time vs. at `nft -f` time

- [ ] **Step 1: Add to ARCHITECTURE.md**

A new section after §3 (top-level option surface), titled "Eval-time validation via nix-libnet". List the libnet-typed fields and note where validation is intentionally deferred (DNAT/SNAT targets, set elements with type-dependent shapes).

- [ ] **Step 2: Add a one-paragraph "Eval-time validation" subsection to README.md "Status"**

- [ ] **Step 3: Commit**

```bash
git add docs/ARCHITECTURE.md README.md
git commit -m "docs: Document nix-libnet integration scope"
```

---

## PR 2 — Honesty + cleanup (S, mostly mechanical)

These are the polish items from the holistic review. Each is small; can ship as one or two PRs.

- [ ] Convert all `#`-stacked headers to `/* … */` blocks. ~22 files (full list in the holistic-review report under "Important issues / Comment-style conversions").
- [ ] Add module headers to the 32 files that lack them (full list under "Important issues / Module headers entirely missing").
- [ ] Strip "Tasks NN-NN" references from production source: `ir-dispatch.nix:10`, `rules-common.nix:5`, `priority-bands.nix:3-4`, `zone-predicate.nix:9`. Replace with role-based phrasing.
- [ ] Extract the 6-element rule-kind list (`["filter" "icmp" "mangle" "dnat" "snat" "redirect"]`) into a single source — e.g. `lib/rule-kinds.nix` exporting `kinds = [...]; chainOf = { filter = ...; ...; }`.
- [ ] Extract `ruleCoreFieldsExcept` helper into `rules-common.nix`. Removes duplicated `let baseFields = lib.filterAttrs …` pattern from dnat/snat/redirect/mangle.
- [ ] Reconcile `tables` field duplication between `rules-common.nix:dispatchFields.tables` and `objects/_common.nix:commonFields.tables`. Make _common the single source.
- [ ] Export `v4Families`/`v6Families` from `lib/family.nix` and replace inline copies in `zone-predicate.nix`, `render-objects.nix`, `ir-rules.nix`.
- [ ] Wire `lib/priority-bands.nix` constants into helpers (loopback-accept, conntrack-baseline, rpfilter, flow-offload). Replace hardcoded `priority = 50` and `100` with `bands.preDispatch` / `bands.early`.
- [ ] Strip unused arguments (`{ name, ... }` and `{ config, ... }` where unused) — ~22 + 19 files.
- [ ] Drop unused exports: `refs.missingNames`, `family.l3`, the `_isNode`/`_nodeName` markers if not consumed by stages 7-10. (After PR 3 below decides whether to consume them.)
- [ ] Replace magic numbers in `assemble.nix` (-100, 100, -150) with named constants.
- [ ] Update README's "feature-complete per the initial design spec" claim — replace with an accurate status section that distinguishes implemented from stubbed.

Commit per logical group; the whole PR should be reviewable as a series of small mechanical commits.

---

## PR 3 — Renderers + dispatch (M, the real implementation gap)

This is where the project goes from MVP-scaffolding to actually-feature-complete.

- [ ] **Implement icmp renderer** (`modules/pipeline/renderers/icmp.nix`). Render per-family ICMP type matches; dual-stack zones split into two rules. Add `tests/render/icmp-basic.nix`.
- [ ] **Implement mangle renderer.** `setMark` → `meta mark set N`; `setDscp` → `ip dscp set …` / `ip6 dscp set …`. Add render test.
- [ ] **Implement dnat renderer.** Resolve node-name `forwardTo` against `cfg.nodes.<name>.address.*` at render time. Emit `dnat to <addr>:<port>`. Add render test.
- [ ] **Implement snat renderer.** `translateTo = null` → `masquerade`. Otherwise `snat to <endpoint>`. Add render test.
- [ ] **Implement redirect renderer.** Emit `redirect to :<port>`. Add render test.
- [ ] **Fix filter renderer family bug** — `srcSet`/`dstSet` should pick `protocol = "ip"` vs `"ip6"` based on `resolvedRule.family`. Add IPv6-set render test.
- [ ] **Implement per-zone subchain emission in `assemble.nix`**. Each `irDispatch.<table::chain>` entry produces (a) one major chain with dispatch jumps, (b) one regular subchain per source zone with the rules. Hierarchy jumps (parent → child) per the architecture doc. Add render snapshot test.
- [ ] **Apply priority-band sort** in `assemble.nix` when assembling rules. Verify with snapshot tests that helper rules land in band 50/100.
- [ ] **Wire `objects.chains` into rendering** — user-declared chains emit as named regular chains in their host table.
- [ ] **Wire `tables.<name>.baseChains.*` overrides** into `assemble.nix:baseChainConfig` so user-supplied policy/priority/extraRules/devices flow through.
- [ ] **Wire ct.{helpers,timeouts,expectations}, secmarks, synproxies, tunnels object renderers**. Currently stubs returning `{}`. Add render tests for each.
- [ ] **Expand integration smoke** to exercise NAT, mangle, ICMP, sets-with-rules, dual-stack rules. Verify each parses with `nft -c`.
- [ ] **Add VM test for cooperative mode** — verify nftables.service does not flush ruleset and our tables coexist with a hand-authored one.

Commit per kind / per concern. Order: filter family fix → icmp → mangle → nat trio → object emit → subchain assembly → priority sort → integration extensions.

---

## PR 4 — Validation hardening (S/M)

After PRs 1 + 3 land, validation can lean on libnet types + the renderer's name-resolution to add the missing checks.

- [ ] Add reference-existence checks in `validate.nix`:
  - rule.from / rule.to → must reference an existing zone, node, or `local`/`any`
  - rule.tables → each entry must reference a declared table
  - rule.counter / .limit / .quota / .ctHelper / .ctTimeout / .ctExpectation / .synproxy / .secmark / .flowtable / .tunnel → must reference an existing object of the right kind
  - rule.match.srcSet / .dstSet → must reference an existing set
  - rule.match.{srcAddresses,dstAddresses}.ipv4 vs ipv6 → must be compatible with target table family (libnet types catch the address shape; family compat is per-table)
- [ ] Add zone/node name clash assertion test (already-existing check in validate.nix has no test).
- [ ] Add set type vs table family compatibility check + test.
- [ ] Add chain.table reference check + test.

Each new validation rule pairs with one assertion test that triggers it.

---

## Self-review

- **Spec coverage:** PR 0 fixes the docs path; PR 1 covers all libnet integration points the spec calls out (zones addresses, node addresses, rule match addresses/ports, NAT redirect port, tunnel address/port fields, helper ports). PR 1 deliberately defers DNAT/SNAT endpoint typing because of node-name references — flagged with a TODO. PRs 2-4 close gaps the holistic review surfaced.
- **Placeholder scan:** No "TBD" or "fill in" — every step has actual code or actual file:line refs.
- **Type consistency:** field names match across renderer/IR/option files (forwardTo, translateTo, redirectTo, addresses.ipv4/.ipv6, srcPorts/dstPorts).
- **Scope check:** PR 0 + PR 1 alone is a coherent shippable improvement. PRs 2-4 sequence afterwards each as their own logical unit.

---

## Execution Handoff

Plan complete and saved to `docs/plans/2026-04-25-libnet-and-cleanup.md`. Two execution options:

1. **Subagent-Driven (recommended)** — same flow as the original plan: fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — tasks performed in the current session with checkpoints.

Which approach?
