# nixos-nftfw

A NixOS module that generates nftables firewall configuration.
Zones, nodes, and kind-typed rules compile to nftables text through a
10-stage pipeline built on nix-libnet and nix-nftypes.

## Status

Pre-release — alpha. The option surface, eval-time validation, and the
filter rule path are functional and tested end-to-end with `nft -c`.
Several rule kinds and dispatch features are stubbed pending the next
implementation pass.

### What works today

- Full option surface: zones, nodes, six rule kinds, Layer A primitives
  (tables, chains, sets, maps, counters, quotas, limits, ct.*, flowtables,
  secmarks, synproxies, tunnels, ruleset passthrough)
- Eval-time validation via nix-libnet — IP addresses, CIDR blocks, ports,
  and endpoint fields are typed against libnet's NixOS-aware types so
  malformed values are rejected by `nixos-rebuild` instead of silently
  reaching `nft -f`
- Filter rule rendering end-to-end: zone-aware match composition, address
  and port matches, named-counter / named-limit / flowtable / ct-helper
  references, all six verdict forms (accept/drop/reject/continue/return
  + jumpTo/gotoTo)
- Authoritative and cooperative modes (counter-defaults flushRuleset to
  avoid clobbering other modules' tables in cooperative mode)
- 10-stage compilation pipeline with IR for zones/tables/rules/dispatch
  and direct composition for renderers
- F3 family scoping: global zones/objects, per-table emission, dual-stack
  split, lazy `main` table synthesis when rules but no tables are declared
- 8 opt-in helpers (loopback-accept, stop-ruleset, conntrack-baseline,
  rpfilter, flow-offload, ip-forwarding, kernel-hardening, defaults)
- Test suite: pure-eval (option surface), golden IR snapshots, render
  snapshots (filter only), assertion tests for validation rules and
  libnet-typed input rejection, integration test via `unshare -rn nft -c`,
  and a single-host VM test

### What is stubbed or partial

- **5 of 6 rule renderers (icmp, mangle, dnat, snat, redirect)** are
  one-line stubs returning an empty statement list. Rules of these kinds
  evaluate, validate, and place into chains correctly but emit no
  nftables output yet. (Coming in PR 3.)
- **Per-zone dispatch subchains** described in ARCHITECTURE.md are
  computed in the dispatch IR but not yet emitted as separate nft
  chains — they're flattened into the parent chain. (PR 3.)
- **Priority-band sorting** is unwired: rules emit in attrset-iteration
  order, not band order. Helper priorities (50, 100) are correctly set
  on the rule fragments but not honoured at emission time. (PR 3.)
- **`objects.chains`** (the R4 chain-centric escape) accepts user input
  but the pipeline does not yet emit user-declared chains. (PR 3.)
- **`tables.<name>.baseChains.*` overrides** (custom policy/priority
  per base chain) are accepted but not honoured by the assembler. (PR 3.)
- **Object render emit for ct.helpers, ct.timeouts, ct.expectations,
  secmarks, synproxies, tunnels** is stubbed; only sets/maps/counters/
  quotas/limits/flowtables emit. (PR 3.)
- **IPv6 set matching** in filter rules emits an IPv4-shaped match
  (hardcoded `protocol = "ip"`); needs family-aware switching. (PR 3.)
- **DNAT/SNAT endpoint validation** is deferred to allow node-name
  references like `"webserver:80"`; the renderer's node-resolution
  pass will tighten this. (PR 3.)
- **Cross-reference validation** (rule references nonexistent zone /
  set / counter / table) is not yet enforced beyond zone parent and
  node→zone refs. (PR 4.)

## Documentation

| Document | Path |
|----------|------|
| Architecture overview | `docs/ARCHITECTURE.md` |
| Full design spec | `docs/specs/2026-04-24-nixos-nftfw-design.md` |
| Implementation plan (initial build) | `docs/plans/2026-04-24-nixos-nftfw.md` |
| Cleanup + libnet plan (current) | `docs/plans/2026-04-25-libnet-and-cleanup.md` |

## Usage

```nix
{
  inputs.nixos-nftfw.url = "github:petohorvath/nixos-nftfw";

  outputs = { self, nixpkgs, nixos-nftfw, ... }: {
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ nixos-nftfw.nixosModules.default ];
    };
  };
}
```
