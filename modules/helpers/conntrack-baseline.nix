# Helper: accept established/related connections and drop invalid ones.
#
# Adds two priority-100 filter rules. Defaults to enabled in authoritative
# mode (sensible default for an own-the-firewall config).
{ lib }:

{ config, ... }:

let
  cfg = config.networking.nftfw;
  hcfg = cfg.helpers.conntrackBaseline;
in {
  options.networking.nftfw.helpers.conntrackBaseline = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.authoritative;
      description = ''
        Add two priority-100 filter rules: accept established/related
        connections, and drop invalid ones. Defaults to enabled in
        authoritative mode.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && hcfg.enable) {
    networking.nftfw.rules.filter = {
      _helper-conntrack-est-rel = {
        priority = 100;
        from = "any";
        to = "any";
        match.ct.state = [ "established" "related" ];
        verdict = "accept";
      };
      _helper-conntrack-invalid = {
        priority = 100;
        from = "any";
        to = "any";
        match.ct.state = [ "invalid" ];
        verdict = "drop";
      };
    };
  };
}
