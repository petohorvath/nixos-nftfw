{ lib }:

{ config, ... }:

{
  options.networking.nftfw.objects.synproxies = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { options = { }; }));
    default = { };
    description = "Named synproxy objects.";
  };
}
