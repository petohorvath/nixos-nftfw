{ lib }:

{ config, ... }:

{
  options.networking.nftfw.nodes = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { options = { }; }));
    default = { };
    description = "Named network nodes.";
  };
}
