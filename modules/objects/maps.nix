{ lib }:

{ config, ... }:

let
  mapSubmodule = { name, ... }: {
    options = {
      type = lib.mkOption {
        type = lib.types.either lib.types.str (lib.types.listOf lib.types.str);
        description = "Key type (e.g. \"ifname\", \"ipv4_addr\", or a concatenated list).";
      };
      map = lib.mkOption {
        type = lib.types.either lib.types.str (lib.types.listOf lib.types.str);
        description = "Value type (e.g. \"verdict\", \"inet_service\", or a concatenated list).";
      };
      flags = lib.mkOption {
        type = lib.types.listOf (lib.types.enum [ "constant" "interval" "timeout" "dynamic" ]);
        default = [ ];
        description = "nftables map flags.";
      };
      elements = lib.mkOption {
        type = lib.types.listOf lib.types.unspecified;
        default = [ ];
        description = "Initial map entries. Shape depends on `type` and `map`.";
      };
      timeout = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Default entry TTL in seconds (maps with `timeout` flag).";
      };
      size = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Maximum entry count hint.";
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
  options.networking.nftfw.objects.maps = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule mapSubmodule);
    default = { };
    description = "Named nftables maps and verdict maps.";
  };
}
