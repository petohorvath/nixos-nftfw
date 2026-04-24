{ lib }:

{ config, ... }:

{
  options.networking.nftfw.objects.chains = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { options = { }; }));
    default = { };
    description = "Named chain objects.";
  };
}
