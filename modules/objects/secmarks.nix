{ lib }:

{ config, ... }:

{
  options.networking.nftfw.objects.secmarks = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { options = { }; }));
    default = { };
    description = "Named secmark objects.";
  };
}
