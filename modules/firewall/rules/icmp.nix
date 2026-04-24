{ lib }:

{ config, ... }:

{
  options.networking.nftfw.rules.icmp = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { options = { }; }));
    default = { };
    description = "Named ICMP rules.";
  };
}
