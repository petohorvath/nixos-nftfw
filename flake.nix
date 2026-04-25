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
        lib = nixpkgs.lib;
        nftlib = nix-nftypes.lib;
        libnet = nix-libnet.lib;
      };
      nixosModules.nftfw = self.nixosModules.default;

      formatter = forEach (s: nixpkgs.legacyPackages.${s}.nixfmt-rfc-style);
      checks = forEach (s:
        let
          pkgs = nixpkgs.legacyPackages.${s};
          libnet = nix-libnet.lib;
          nftlib = nix-nftypes.lib;
          mkTest = path: import path { inherit pkgs libnet nftlib; };
          mkVmTest = path: import path { inherit pkgs libnet nftlib self; };
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
          eval-rules-filter = mkTest ./tests/eval/rules-filter.nix;
          eval-rules-icmp = mkTest ./tests/eval/rules-icmp.nix;
          eval-rules-mangle = mkTest ./tests/eval/rules-mangle.nix;
          eval-rules-nat = mkTest ./tests/eval/rules-nat.nix;
          assertion-missing-zone = mkTest ./tests/assertions/missing-zone.nix;
          assertion-cyclic-parent = mkTest ./tests/assertions/cyclic-parent.nix;
          assertion-zone-bad-ipv4 = mkTest ./tests/assertions/zone-bad-ipv4.nix;
          assertion-zone-bad-ipv6 = mkTest ./tests/assertions/zone-bad-ipv6.nix;
          assertion-node-bad-address = mkTest ./tests/assertions/node-bad-address.nix;
          assertion-rule-bad-port = mkTest ./tests/assertions/rule-bad-port.nix;
          assertion-rule-bad-address = mkTest ./tests/assertions/rule-bad-address.nix;
          ir-zones-basic = mkTest ./tests/ir/zones-basic.nix;
          ir-table-lazy-main = mkTest ./tests/ir/table-lazy-main.nix;
          ir-rule-resolution = mkTest ./tests/ir/rule-resolution.nix;
          ir-dispatch-basic = mkTest ./tests/ir/dispatch-basic.nix;
          render-filter-basic = mkTest ./tests/render/filter-basic.nix;
          eval-helper-loopback = mkTest ./tests/eval/helper-loopback.nix;
          eval-helper-stop-ruleset = mkTest ./tests/eval/helper-stop-ruleset.nix;
          eval-helper-kernel-hardening = mkTest ./tests/eval/helper-kernel-hardening.nix;
          eval-helper-conntrack-baseline = mkTest ./tests/eval/helper-conntrack-baseline.nix;
          eval-helper-rpfilter = mkTest ./tests/eval/helper-rpfilter.nix;
          eval-helper-flow-offload = mkTest ./tests/eval/helper-flow-offload.nix;
          eval-helper-ip-forwarding = mkTest ./tests/eval/helper-ip-forwarding.nix;
          eval-helper-defaults = mkTest ./tests/eval/helper-defaults.nix;
          integration-smoke = mkTest ./tests/integration/smoke.nix;
          vm-single-host = mkVmTest ./tests/vm/single-host.nix;
        });
    };
}
