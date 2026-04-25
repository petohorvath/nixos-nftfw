/*
  Kind-typed filter rule submodule (`networking.nftfw.rules.filter.<name>`).

  Uses the common rule-core fields (match + statements + verdict +
  dispatch from rules-common.nix). Default verdict is "accept"; rules
  are dispatched into input/forward/output chains based on the (from, to)
  zone tuple by the pipeline.
*/
{ lib }:

{ config, libnet, ... }:

let
  common = import ../rules-common.nix { inherit lib libnet; };

  filterRuleSubmodule = { name, ... }: {
    options = common.ruleCoreFields;
    config = {
      verdict = lib.mkDefault "accept";
    };
  };
in {
  options.networking.nftfw.rules.filter = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule filterRuleSubmodule);
    default = { };
    description = ''
      Kind-typed filter rules. Each entry is dispatched into input,
      forward, or output chains based on (from, to) zones; "local"
      acts as a marker for the host itself. Default verdict is accept.
    '';
  };
}
