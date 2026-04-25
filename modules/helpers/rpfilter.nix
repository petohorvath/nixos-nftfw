/*
  Helper: reverse-path filter via fib saddr oif lookup.

  Drops packets whose source address has no route back via the input
  interface. Opt-in only (default false).
*/
{ lib }:

{ config, ... }:

let
  cfg = config.networking.nftfw;
  hcfg = cfg.helpers.rpfilter;
  bands = import ../../lib/priority-bands.nix;

  fibFlags = if hcfg.strict then "saddr . iif . mark" else "saddr . mark";
in {
  options.networking.nftfw.helpers.rpfilter = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Drop packets whose source address has no route back via the input interface.";
    };
    strict = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Strict mode (require packet's iif to match the route's oif). Loose mode only requires any route to exist.";
    };
    exemptInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "lo" ];
      description = "Interfaces exempt from rpfilter checks.";
    };
  };

  config = lib.mkIf (cfg.enable && hcfg.enable) {
    networking.nftfw.rules.filter._helper-rpfilter = {
      priority = bands.preDispatch;
      from = "any";
      to = "any";
      match.extraMatch = lib.optional (hcfg.exemptInterfaces != [ ]) {
        match = {
          left = { meta = { key = "iifname"; }; };
          right = { set = hcfg.exemptInterfaces; };
          op = "!=";
        };
      };
      extraStatements = [
        {
          match = {
            left = { fib = { result = "oif"; flags = lib.splitString " . " fibFlags; }; };
            right = false;
            op = "==";
          };
        }
      ];
      verdict = "drop";
    };
  };
}
