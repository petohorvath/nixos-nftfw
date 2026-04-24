{ lib }:

{ config, ... }:

let
  inherit (import ./_common.nix { inherit lib; }) commonFields;

  synproxySubmodule = { name, ... }: {
    options = {
      mss = lib.mkOption {
        type = lib.types.int;
        description = "TCP MSS advertised by the proxy.";
      };
      wscale = lib.mkOption {
        type = lib.types.int;
        description = "TCP window-scale advertised by the proxy.";
      };
      flags = lib.mkOption {
        type = lib.types.listOf (lib.types.enum [ "timestamp" "sack-perm" ]);
        default = [ ];
        description = "SYN-proxy flags.";
      };
    } // commonFields;
  };
in {
  options.networking.nftfw.objects.synproxies = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule synproxySubmodule);
    default = { };
    description = "Named SYN-proxy objects for SYN-flood protection.";
  };
}
