/*
  Secmark submodule (`networking.nftfw.objects.secmarks.<name>`).

  Named secmark objects for SELinux/AppArmor packet labelling. Field:
  `context` (the security context string), plus the shared
  `tables`/`comment` from commonFields.
*/
{ lib }:

{ ... }:

let
  inherit (import ./_common.nix { inherit lib; }) commonFields;

  secmarkSubmodule = { ... }: {
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
