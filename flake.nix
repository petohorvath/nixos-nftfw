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
      checks = forEach (s:
        let
          pkgs = nixpkgs.legacyPackages.${s};
          libnet = nix-libnet.lib;
          nftlib = nix-nftypes.lib;
          mkTest = path: import path { inherit pkgs libnet nftlib; };
        in {
          eval-enable = mkTest ./tests/eval/enable.nix;
          eval-namespaces = mkTest ./tests/eval/namespaces.nix;
          eval-zones = mkTest ./tests/eval/zones.nix;
          eval-nodes = mkTest ./tests/eval/nodes.nix;
          eval-sets = mkTest ./tests/eval/sets.nix;
          eval-maps = mkTest ./tests/eval/maps.nix;
          eval-stateful = mkTest ./tests/eval/stateful.nix;
          eval-ct = mkTest ./tests/eval/ct.nix;
          eval-objects-misc = mkTest ./tests/eval/objects-misc.nix;
          eval-tables = mkTest ./tests/eval/tables.nix;
          eval-chains = mkTest ./tests/eval/chains.nix;
        });
    };
}
