{ lib }:

{ config, ... }:

{
  options.networking.nftfw.rules.dnat = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { options = { }; }));
    default = { };
    description = "Named DNAT rules.";
  };
}
