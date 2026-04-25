{ lib }:

{ config, libnet, ... }:

let
  common = import ../rules-common.nix { inherit lib libnet; };

  icmpRuleSubmodule = { name, ... }: {
    options = common.ruleCoreFields // {
      icmp.v4Types = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          ICMPv4 message types (e.g. "echo-request", "destination-unreachable",
          "time-exceeded"). Rendered into ip-family rules.
        '';
      };
      icmp.v6Types = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          ICMPv6 message types (e.g. "echo-request", "nd-neighbor-solicit").
          Rendered into ip6-family rules.
        '';
      };
    };
    config = {
      verdict = lib.mkDefault "accept";
    };
  };
in {
  options.networking.nftfw.rules.icmp = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule icmpRuleSubmodule);
    default = { };
    description = ''
      Kind-typed ICMP rules. Each entry produces separate ip and ip6
      rules per `icmp.v4Types`/`icmp.v6Types`. Default verdict is accept.
    '';
  };
}
