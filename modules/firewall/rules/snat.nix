{ lib }:

{ config, ... }:

{
  options.networking.nftfw.rules.snat = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { options = { }; }));
    default = { };
    description = "Named SNAT rules.";
  };
}
