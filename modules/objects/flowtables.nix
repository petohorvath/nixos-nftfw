{ lib }:

{ config, ... }:

let
  inherit (import ./_common.nix { inherit lib; }) commonFields;

  flowtableSubmodule = { name, ... }: {
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
