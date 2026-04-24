{ lib }:

{ config, ... }:

{
  options.networking.nftfw.objects.tunnels = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { options = { }; }));
    default = { };
    description = "Named tunnel objects.";
  };
}
