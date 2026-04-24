{ lib }:

{ config, ... }:

{
  options.networking.nftfw.rules.redirect = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { options = { }; }));
    default = { };
    description = "Named redirect rules.";
  };
}
