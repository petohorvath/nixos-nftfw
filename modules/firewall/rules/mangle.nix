/*
  Kind-typed mangle rule submodule (`networking.nftfw.rules.mangle.<name>`).

  Emits into mangle-prerouting. Adds `setMark` and `setDscp` fields;
  drops the `to` dispatch field (destination is unknown at prerouting).
  No default verdict — mangle rules are non-terminal by design.
*/
{ lib }:

{ libnet, ... }:

let
  common = import ../rules-common.nix { inherit lib libnet; };

  # Drop `to` from ruleCoreFields (mangle prerouting has no destination zone)
  baseFields = common.ruleCoreFieldsExcept [ "to" ];

  mangleRuleSubmodule = { ... }: {
    options = baseFields // {
      setMark = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Set the packet's fwmark to this value.";
      };
      setDscp = lib.mkOption {
        type = lib.types.nullOr (lib.types.oneOf [ lib.types.int lib.types.str ]);
        default = null;
        description = ''
          Set the IP DSCP field. Either an int (0-63) or a symbolic name
          (e.g. "ef", "af41", "cs1").
        '';
      };
    };
  };
in {
  options.networking.nftfw.rules.mangle = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule mangleRuleSubmodule);
    default = { };
    description = ''
      Kind-typed mangle rules. Run in mangle-prerouting; classify or
      mark traffic by source zone. No `to` field (destination is
      unknown at prerouting); no default verdict (mangle is
      non-terminal — packets continue through other tables).
    '';
  };
}
