{ lib }:

{ config, ... }:

{
  options.networking.nftfw.rules.mangle = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { options = { }; }));
    default = { };
    description = "Named mangle rules.";
  };
}
