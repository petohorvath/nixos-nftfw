/*
  Meta-helper: sensible defaults bundle.

  Imports loopback-accept, conntrack-baseline, and stop-ruleset
  helpers. Their individual `enable` options default to
  `cfg.authoritative`, so users who enable authoritative mode get
  the full bundle out of the box. Users who want the bundle in
  cooperative mode can `imports = [ <nftfw>/modules/helpers/defaults.nix ]`
  and set the individual helper enables to true, OR set
  `networking.nftfw.helpers.defaults.enable = true` to force-enable
  all three.
*/
{ lib }:

{ config, ... }:

let
  cfg = config.networking.nftfw;
  hcfg = cfg.helpers.defaults;
in {
  options.networking.nftfw.helpers.defaults = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Force-enable the full defaults bundle (loopback-accept,
        conntrack-baseline, stop-ruleset) even in cooperative mode.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && hcfg.enable) {
    networking.nftfw.helpers.loopbackAccept.enable = lib.mkDefault true;
    networking.nftfw.helpers.conntrackBaseline.enable = lib.mkDefault true;
    networking.nftfw.helpers.stopRuleset.enable = lib.mkDefault true;
  };
}
