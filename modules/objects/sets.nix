{ lib }:

{ config, ... }:

{
  options.networking.nftfw.objects.sets = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { options = { }; }));
    default = { };
    description = "Named set objects.";
  };
}
