/*
  Helper: apply a baseline of kernel sysctls that harden the network stack.

  Opt-in only (default false) because kernel sysctls are intrusive and
  may conflict with other modules or user preferences.
*/
{ lib }:

{ config, ... }:

let
  cfg = config.networking.nftfw;
  hcfg = cfg.helpers.kernelHardening;
in {
  options.networking.nftfw.helpers.kernelHardening = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Apply a baseline of kernel sysctls that harden the IPv4/IPv6
        network stack: enable rp_filter, drop accept_redirects,
        accept_source_route, log martian packets, ignore broadcast
        ICMP echoes.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && hcfg.enable) {
    boot.kernel.sysctl = {
      "net.ipv4.conf.all.rp_filter" = lib.mkDefault 1;
      "net.ipv4.conf.default.rp_filter" = lib.mkDefault 1;
      "net.ipv4.conf.all.accept_redirects" = lib.mkDefault 0;
      "net.ipv4.conf.default.accept_redirects" = lib.mkDefault 0;
      "net.ipv4.conf.all.secure_redirects" = lib.mkDefault 0;
      "net.ipv4.conf.default.secure_redirects" = lib.mkDefault 0;
      "net.ipv4.conf.all.accept_source_route" = lib.mkDefault 0;
      "net.ipv4.conf.default.accept_source_route" = lib.mkDefault 0;
      "net.ipv4.conf.all.log_martians" = lib.mkDefault 1;
      "net.ipv4.conf.default.log_martians" = lib.mkDefault 1;
      "net.ipv4.icmp_echo_ignore_broadcasts" = lib.mkDefault 1;
      "net.ipv6.conf.all.accept_redirects" = lib.mkDefault 0;
      "net.ipv6.conf.default.accept_redirects" = lib.mkDefault 0;
      "net.ipv6.conf.all.accept_source_route" = lib.mkDefault 0;
      "net.ipv6.conf.default.accept_source_route" = lib.mkDefault 0;
    };
  };
}
