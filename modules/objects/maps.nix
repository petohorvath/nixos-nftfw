{ lib }:

{ config, ... }:

{
  options.networking.nftfw.objects.maps = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { options = { }; }));
    default = { };
    description = "Named map objects.";
  };
}
