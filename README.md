# nixos-nftfw

A NixOS module that generates nftables firewall configuration.

## Status

Pre-release. The module's option surface and compilation pipeline
are under active development. See
`docs/superpowers/specs/2026-04-24-nixos-nftfw-design.md` for the
design and `docs/plans/2026-04-24-nixos-nftfw.md` for the
implementation plan.

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
