{ lib }:

{ config, ... }:

{
  options.networking.nftfw.objects.tables = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { options = { }; }));
    default = { };
    description = "Named table objects.";
  };
}
