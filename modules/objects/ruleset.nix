{ lib }:

{ config, ... }:

{
  options.networking.nftfw.objects.ruleset = lib.mkOption {
    type = lib.types.nullOr lib.types.attrs;
    default = null;
    description = "Raw nftypes ruleset value; appended to networking.nftables.ruleset when set.";
  };
}
