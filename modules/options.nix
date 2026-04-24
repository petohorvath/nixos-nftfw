{ lib }:

{ config, ... }:

{
  options.networking.nftfw = {
    enable = lib.mkEnableOption "nftfw firewall module";

    authoritative = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When true, the module owns the kernel firewall: flushes the
        ruleset at load and disables networking.firewall. When false,
        coexists with other nftables contributors.
      '';
    };

    _internal.ir = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      internal = true;
      readOnly = true;
      description = "Computed IR for debugging. TODO: remove once stable.";
    };
  };
}
