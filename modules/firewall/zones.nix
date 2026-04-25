{ lib }:

{ config, libnet, ... }:

let
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
        type = lib.types.listOf libnet.types.ipv4Cidr;
        default = [ ];
        description = "IPv4 addresses or CIDR blocks that belong to this zone.";
      };
      addresses.ipv6 = lib.mkOption {
        type = lib.types.listOf libnet.types.ipv6Cidr;
        default = [ ];
        description = "IPv6 addresses or CIDR blocks that belong to this zone.";
      };
      conntrackZone = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Optional nftables conntrack zone id for multi-WAN isolation.";
      };
      ingressExpression = lib.mkOption {
        type = lib.types.nullOr lib.types.attrs;
        default = null;
        description = ''
          Raw nftypes match expression that replaces the ingress predicate
          auto-derived from `interfaces` and `addresses`. Typed as attrs
          for now; will be refined to nftypes' expression type in a
          follow-up once it is wired in.
        '';
      };
      egressExpression = lib.mkOption {
        type = lib.types.nullOr lib.types.attrs;
        default = null;
        description = ''
          Raw nftypes match expression that replaces the egress predicate
          auto-derived from `interfaces` and `addresses`.
        '';
      };
      comment = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Free-form comment carried into the generated ruleset.";
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
