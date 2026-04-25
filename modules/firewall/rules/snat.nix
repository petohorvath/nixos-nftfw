/*
  Kind-typed SNAT rule submodule (`networking.nftfw.rules.snat.<name>`).

  Emits into nat-postrouting. Adds `translateTo` (endpoint string or
  null for masquerade); drops `verdict`, `jumpTo`, `gotoTo` (verdict is
  implicitly the SNAT/masquerade rewrite). Only emits into L3-capable
  families (ip/ip6/inet).
*/
{ lib }:

{ config, libnet, ... }:

let
  common = import ../rules-common.nix { inherit lib libnet; };

  baseFields = common.ruleCoreFieldsExcept [ "verdict" "jumpTo" "gotoTo" ];

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

          Validation against libnet.types.endpoint is deferred until
          node-name resolution lands in the renderer; today the field
          is `str` to accept the bare-name forms.
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
