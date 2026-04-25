/*
  Helper: declare a flowtable and enrol established/related forwarded traffic.

  Opt-in only (default false). Requires interfaces to be specified for
  the enrolment rule to be added.
*/
{ lib }:

{ config, ... }:

let
  cfg = config.networking.nftfw;
  hcfg = cfg.helpers.flowOffload;
in {
  options.networking.nftfw.helpers.flowOffload = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable nftables flow offload for forwarded est/rel traffic.";
    };
    interfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Interfaces enrolled in the flowtable.";
    };
    hardware = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Reserved — request hardware offload (passes through to nftables flowtable flags).";
    };
    zones = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Restrict offload enrolment to traffic between these zones (placeholder — currently unused; offload applies to all forward est/rel).";
    };
  };

  config = lib.mkIf (cfg.enable && hcfg.enable) (lib.mkMerge [
    {
      networking.nftfw.objects.flowtables.offload = {
        hook = "ingress";
        priority = 0;
        devices = hcfg.interfaces;
      };
    }
    (lib.mkIf (hcfg.interfaces != [ ]) {
      networking.nftfw.rules.filter._helper-flow-offload = {
        priority = 100;
        from = "any";
        to = "any";
        match.ct.state = [ "established" "related" ];
        flowtable = "offload";
        verdict = null;
      };
    })
  ]);
}
