/*
  Kind-typed redirect rule submodule (`networking.nftfw.rules.redirect.<name>`).

  Emits into nat-prerouting. Adds `redirectTo` (local port for transparent
  proxy); drops `to`, `verdict`, `jumpTo`, `gotoTo` (verdict is implicitly
  the redirect). Only emits into L3-capable families (ip/ip6/inet).
*/
{ lib }:

{ config, libnet, ... }:

let
  common = import ../rules-common.nix { inherit lib libnet; };

  baseFields = lib.filterAttrs
    (n: _: !(builtins.elem n [ "to" "verdict" "jumpTo" "gotoTo" ]))
    common.ruleCoreFields;

  redirectRuleSubmodule = { name, ... }: {
    options = baseFields // {
      redirectTo = lib.mkOption {
        type = libnet.types.port;
        description = "Local port to redirect matching traffic to (transparent proxy).";
      };
    };
  };
in {
  options.networking.nftfw.rules.redirect = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule redirectRuleSubmodule);
    default = { };
    description = ''
      Kind-typed redirect rules. Run in nat-prerouting; rewrite the
      destination to a local port (used for transparent proxies).
    '';
  };
}
