{ lib }:

{ config, ... }:

{
  options.networking.nftfw.objects.ct.helpers = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { options = { }; }));
    default = { };
    description = "Conntrack helpers.";
  };
  options.networking.nftfw.objects.ct.timeouts = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { options = { }; }));
    default = { };
    description = "Conntrack timeout policies.";
  };
  options.networking.nftfw.objects.ct.expectations = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { options = { }; }));
    default = { };
    description = "Conntrack expectations.";
  };
}
