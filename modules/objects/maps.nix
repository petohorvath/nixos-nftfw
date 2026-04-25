/*
  Map submodule (`networking.nftfw.objects.maps.<name>`).

  Named nftables maps and verdict maps auto-emitted to all tables.
  Fields: `type` (key type), `map` (value type), `flags`, `elements`,
  `timeout`, `size`, plus the shared `tables`/`comment` from commonFields.
*/
{ lib }:

{ ... }:

let
  inherit (import ./_common.nix { inherit lib; }) commonFields;

  mapSubmodule = { ... }: {
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
    } // commonFields;
  };
in {
  options.networking.nftfw.objects.maps = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule mapSubmodule);
    default = { };
    description = "Named nftables maps and verdict maps.";
  };
}
