/*
  Table submodule (`networking.nftfw.objects.tables.<name>`).

  Each table is a named nftables table and an emission target for rules
  and objects. Fields: `family`, `flags`, `comment`, `extraContent`
  (raw nftypes escape), and `baseChains.*` overrides for hook priority,
  policy, and extra rules on each base chain.
*/
{ lib }:

{ config, ... }:

let
  # base chain submodule factory: takes an attrset of extra field options
  baseChainSubmodule = extraFields: { ... }: {
    options = {
      priority = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Hook priority; null leaves the default for this chain type.";
      };
      extraRules = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        description = "Raw nftypes rule fragments appended at the end of this base chain.";
      };
    } // extraFields;
  };

  filterBaseChain = baseChainSubmodule {
    policy = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "accept" "drop" ]);
      default = null;
      description = "Chain policy; null lets the module pick the authoritative/cooperative default.";
    };
  };
  natBaseChain = baseChainSubmodule { };
  mangleBaseChain = baseChainSubmodule { };
  netdevBaseChain = baseChainSubmodule {
    devices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Interfaces bound to this netdev-family base chain.";
    };
  };

  tableSubmodule = { name, ... }: {
    options = {
      family = lib.mkOption {
        type = lib.types.enum [ "ip" "ip6" "inet" "arp" "bridge" "netdev" ];
        description = "nftables table family.";
      };
      flags = lib.mkOption {
        type = lib.types.listOf (lib.types.enum [ "dormant" "owner" "persist" ]);
        default = [ ];
        description = "nftables table flags.";
      };
      comment = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Free-form comment carried into the generated ruleset.";
      };
      extraContent = lib.mkOption {
        type = lib.types.nullOr lib.types.attrs;
        default = null;
        description = ''
          Raw nftypes content appended to this table's body verbatim.
          Use for nftables constructs the module does not model directly.
        '';
      };
      baseChains = {
        input            = lib.mkOption { type = lib.types.nullOr (lib.types.submodule filterBaseChain);  default = null; description = "Override for the filter input base chain."; };
        forward          = lib.mkOption { type = lib.types.nullOr (lib.types.submodule filterBaseChain);  default = null; description = "Override for the filter forward base chain."; };
        output           = lib.mkOption { type = lib.types.nullOr (lib.types.submodule filterBaseChain);  default = null; description = "Override for the filter output base chain."; };
        natPrerouting    = lib.mkOption { type = lib.types.nullOr (lib.types.submodule natBaseChain);     default = null; description = "Override for the NAT prerouting chain."; };
        natPostrouting   = lib.mkOption { type = lib.types.nullOr (lib.types.submodule natBaseChain);     default = null; description = "Override for the NAT postrouting chain."; };
        manglePrerouting = lib.mkOption { type = lib.types.nullOr (lib.types.submodule mangleBaseChain);  default = null; description = "Override for the mangle prerouting chain."; };
        ingress          = lib.mkOption { type = lib.types.nullOr (lib.types.submodule netdevBaseChain);  default = null; description = "Override for the netdev/bridge ingress chain."; };
        egress           = lib.mkOption { type = lib.types.nullOr (lib.types.submodule netdevBaseChain);  default = null; description = "Override for the netdev egress chain."; };
      };
    };
  };
in {
  options.networking.nftfw.objects.tables = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule tableSubmodule);
    default = { };
    description = "nftables tables; each is an emission target for global rules/objects.";
  };
}
