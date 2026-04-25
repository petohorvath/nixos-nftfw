# Helper: accept all traffic on the loopback interface.
#
# Defaults to enabled when authoritative mode is on (sensible default
# for an own-the-firewall config). Users can opt out explicitly. In
# cooperative mode the default is off.
{ lib }:

{ config, ... }:

let
  cfg = config.networking.nftfw;
  hcfg = cfg.helpers.loopbackAccept;
in {
  options.networking.nftfw.helpers.loopbackAccept = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.authoritative;
      description = ''
        Add a high-priority filter rule that accepts all traffic on the
        loopback interface. Defaults to enabled in authoritative mode.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && hcfg.enable) {
    networking.nftfw.rules.filter._helper-loopback-accept = {
      priority = 100;
      from = "any";
      to = "local";
      match.extraMatch = [
        { match = { left = { meta = { key = "iifname"; }; }; right = "lo"; op = "=="; }; }
      ];
      verdict = "accept";
    };
  };
}
