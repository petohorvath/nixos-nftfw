{ lib }:

{ config, ... }:

{
  options.networking.nftfw.zones = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { options = { }; }));
    default = { };
    description = "Named firewall zones.";
  };
}
