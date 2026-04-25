# nixos-nftfw

A NixOS module that generates nftables firewall configuration.
Zones, nodes, and kind-typed rules compile to nftables text through a
10-stage pipeline built on nix-libnet and nix-nftypes.

## Status

Feature-complete per the initial design spec. The following are implemented
and tested:

- Full option surface: zones, nodes, six rule kinds, Layer A primitives
  (tables, chains, sets, maps, counters, quotas, limits, ct.*, flowtables,
  secmarks, synproxies, tunnels, ruleset passthrough)
- All eight helpers (stopRuleset, conntrackBaseline, loopbackAccept,
  kernelHardening, flowOffload, rpfilter, ipForwarding, defaults)
- 10-stage compilation pipeline with IR (stages 3–6) and direct composition
  (stages 7–8)
- Authoritative and cooperative modes
- Family scoping (F3): global declarations, per-table emission, dual-stack
  split, lazy `main` table synthesis
- Per-zone subchain dispatch with priority bands and zone hierarchy jumps
- Test suite: pure-eval, golden IR snapshots, render snapshots, assertion
  tests, integration (`nft -c`), and VM tests

## Documentation

| Document | Path |
|----------|------|
| Architecture overview | `docs/ARCHITECTURE.md` |
| Full design spec | `docs/superpowers/specs/2026-04-24-nixos-nftfw-design.md` |
| Implementation plan | `docs/plans/2026-04-24-nixos-nftfw.md` |

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
