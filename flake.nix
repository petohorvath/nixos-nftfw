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
