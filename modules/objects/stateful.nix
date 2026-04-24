{ lib }:

{ config, ... }:

{
  options.networking.nftfw.objects.counters = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { options = { }; }));
    default = { };
    description = "Named counter objects.";
  };
  options.networking.nftfw.objects.quotas = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { options = { }; }));
    default = { };
    description = "Named quota objects.";
  };
  options.networking.nftfw.objects.limits = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { options = { }; }));
    default = { };
    description = "Named limit objects.";
  };
}
