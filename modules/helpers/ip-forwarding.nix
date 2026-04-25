# Helper: enable IP forwarding sysctls for routing/NAT setups.
#
# Sets net.ipv4.ip_forward and/or net.ipv6.conf.all.forwarding.
# Opt-in only (default false).
{ lib }:

{ config, ... }:

let
  cfg = config.networking.nftfw;
  hcfg = cfg.helpers.ipForwarding;
in {
  options.networking.nftfw.helpers.ipForwarding = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable IP forwarding sysctls. Required for routing/NAT.";
    };
    ipv4 = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable IPv4 forwarding when the helper is on.";
    };
    ipv6 = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable IPv6 forwarding when the helper is on.";
    };
  };

  config = lib.mkIf (cfg.enable && hcfg.enable) {
    boot.kernel.sysctl =
      (lib.optionalAttrs hcfg.ipv4 {
        "net.ipv4.ip_forward" = lib.mkDefault 1;
      })
      // (lib.optionalAttrs hcfg.ipv6 {
        "net.ipv6.conf.all.forwarding" = lib.mkDefault 1;
      });
  };
}
