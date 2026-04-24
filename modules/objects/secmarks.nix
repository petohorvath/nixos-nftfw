{ lib }:

{ config, ... }:

let
  inherit (import ./_common.nix { inherit lib; }) commonFields;

  secmarkSubmodule = { name, ... }: {
    options = {
      context = lib.mkOption {
        type = lib.types.str;
        description = "SELinux/AppArmor security context to associate.";
      };
    } // commonFields;
  };
in {
  options.networking.nftfw.objects.secmarks = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule secmarkSubmodule);
    default = { };
    description = "Named secmark objects for SELinux/AppArmor labelling.";
  };
}
