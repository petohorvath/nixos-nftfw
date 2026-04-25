/*
  SYN-proxy submodule (`networking.nftfw.objects.synproxies.<name>`).

  Named SYN-proxy objects for SYN-flood protection. Fields: `mss`
  (advertised TCP MSS), `wscale` (TCP window scale), `flags`
  ("timestamp"/"sack-perm"), plus the shared `tables`/`comment`.
*/
{ lib }:

{ ... }:

let
  inherit (import ./_common.nix { inherit lib; }) commonFields;

  synproxySubmodule = { ... }: {
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
