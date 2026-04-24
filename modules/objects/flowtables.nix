{ lib }:

{ config, ... }:

{
  options.networking.nftfw.objects.flowtables = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { options = { }; }));
    default = { };
    description = "Named flowtable objects.";
  };
}
