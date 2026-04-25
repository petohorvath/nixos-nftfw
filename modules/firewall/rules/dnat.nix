{ lib }:

{ config, ... }:

let
  common = import ../rules-common.nix { inherit lib; };

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
