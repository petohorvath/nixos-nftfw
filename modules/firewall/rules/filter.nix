{ lib }:

{ config, ... }:

{
  options.networking.nftfw.rules.filter = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { options = { }; }));
    default = { };
    description = "Named filter rules.";
  };
}
