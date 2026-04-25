/*
  Flowtable submodule (`networking.nftfw.objects.flowtables.<name>`).

  Named nftables flowtables for kernel-level connection tracking offload.
  Fields: `hook` (always "ingress"), `priority`, `devices` (enrolled
  interfaces), plus the shared `tables`/`comment` from commonFields.
  Only emits into L3-capable families (ip/ip6/inet).
*/
{ lib }:

{ ... }:

let
  inherit (import ./_common.nix { inherit lib; }) commonFields;

  flowtableSubmodule = { ... }: {
    options = {
      hook = lib.mkOption {
        type = lib.types.enum [ "ingress" ];
        default = "ingress";
        description = "Flowtable hook; always \"ingress\" in current nftables.";
      };
      priority = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "Flowtable hook priority.";
      };
      devices = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Interface names enrolled in this flowtable.";
      };
    } // commonFields;
  };
in {
  options.networking.nftfw.objects.flowtables = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule flowtableSubmodule);
    default = { };
    description = "Named flowtable objects for kernel offload.";
  };
}
