{ lib }:

{ config, ... }:

let
  common = import ../rules-common.nix { inherit lib; };

  baseFields = lib.filterAttrs
    (n: _: !(builtins.elem n [ "to" "verdict" "jumpTo" "gotoTo" ]))
    common.ruleCoreFields;

  redirectRuleSubmodule = { name, ... }: {
    options = baseFields // {
      redirectTo = lib.mkOption {
        type = lib.types.int;
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
