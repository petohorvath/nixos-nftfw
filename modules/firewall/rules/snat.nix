{ lib }:

{ config, ... }:

let
  common = import ../rules-common.nix { inherit lib; };

  baseFields = lib.filterAttrs
    (n: _: !(builtins.elem n [ "verdict" "jumpTo" "gotoTo" ]))
    common.ruleCoreFields;

  snatRuleSubmodule = { name, ... }: {
    options = baseFields // {
      translateTo = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          SNAT target. null = masquerade (use the egress interface's
          primary address). Otherwise an endpoint string:
            - "203.0.113.1:8080"
            - ":12000"  (port-only)
            - "[fd00::1]:80"
        '';
      };
    };
  };
in {
  options.networking.nftfw.rules.snat = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule snatRuleSubmodule);
    default = { };
    description = ''
      Kind-typed SNAT rules. Run in nat-postrouting; rewrite source
      address/port. `translateTo = null` is masquerade.
    '';
  };
}
