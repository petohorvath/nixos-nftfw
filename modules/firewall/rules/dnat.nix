/*
  Kind-typed DNAT rule submodule (`networking.nftfw.rules.dnat.<name>`).

  Emits into nat-prerouting. Adds `forwardTo` (endpoint string for the
  DNAT target); drops `to`, `verdict`, `jumpTo`, `gotoTo` (verdict is
  implicitly the DNAT rewrite). Only emits into L3-capable families
  (ip/ip6/inet).
*/
{ lib }:

{ config, libnet, ... }:

let
  common = import ../rules-common.nix { inherit lib libnet; };

  # Drop fields the kind doesn't expose: to (destination is rewritten),
  # and the three verdict fields (verdict is implicitly the dnat).
  baseFields = lib.filterAttrs
    (n: _: !(builtins.elem n [ "to" "verdict" "jumpTo" "gotoTo" ]))
    common.ruleCoreFields;

  dnatRuleSubmodule = { name, ... }: {
    options = baseFields // {
      forwardTo = lib.mkOption {
        type = lib.types.str;
        description = ''
          DNAT target. Endpoint string forms:
            - "node-name:port"     — resolves to nodes.<name>.address.* at render time
            - "192.0.2.1:8080"     — literal endpoint
            - ":8080"              — port-only (preserves destination address)

          Validation against libnet.types.endpoint is deferred until
          node-name resolution lands in the renderer; today the field
          is `str` to accept the bare-name forms.
        '';
      };
    };
  };
in {
  options.networking.nftfw.rules.dnat = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule dnatRuleSubmodule);
    default = { };
    description = ''
      Kind-typed DNAT rules. Run in nat-prerouting; rewrite destination
      address/port for matching traffic. Verdict is implicitly the DNAT
      to `forwardTo`.
    '';
  };
}
