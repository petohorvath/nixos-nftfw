{ lib }:

{ config, ... }:

let
  setSubmodule = { name, ... }: {
    options = {
      type = lib.mkOption {
        type = lib.types.either lib.types.str (lib.types.listOf lib.types.str);
        description = ''
          Set type. Either a single nftables type name (e.g. "ipv4_addr",
          "inet_service", "ether_addr", "mark", "ifname") or a list of
          names for concatenated sets (e.g. [ "ipv4_addr" "inet_service" ]).
        '';
      };
      flags = lib.mkOption {
        type = lib.types.listOf (lib.types.enum [ "constant" "interval" "timeout" "dynamic" ]);
        default = [ ];
        description = "nftables set flags.";
      };
      elements = lib.mkOption {
        type = lib.types.listOf lib.types.unspecified;
        default = [ ];
        description = "Initial set elements. Shape depends on `type`.";
      };
      timeout = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Default element TTL in seconds (sets with `timeout` flag).";
      };
      size = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Maximum element count hint.";
      };
      tables = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = ''
          Emission scope. null = auto-emit to every declared table whose
          family is compatible; list = explicit restriction to named tables.
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
  options.networking.nftfw.objects.sets = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule setSubmodule);
    default = { };
    description = "Named nftables sets.";
  };
}
