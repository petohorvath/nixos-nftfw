# Pipeline aggregator — wires every stage and emits to NixOS options.
{ lib, nftlib }:

{ config, ... }:

let
  cfg = config.networking.nftfw;
  collected = import ./collect.nix { inherit lib cfg; };
  validated = import ./validate.nix { inherit lib collected; };
  irZones = import ./ir-zones.nix { inherit lib nftlib collected; };
  irTables = import ./ir-tables.nix { inherit lib collected; };
  irRules = import ./ir-rules.nix { inherit lib collected irZones irTables; };
  irDispatch = import ./ir-dispatch.nix { inherit lib irZones irRules; };
  renderRules = import ./render-rules.nix { inherit lib nftlib; };
  renderedObjects = import ./render-objects.nix { inherit lib nftlib collected irTables; };
  assembled = import ./assemble.nix {
    inherit lib nftlib irTables irRules irDispatch renderedObjects renderRules cfg;
  };
  emitted = import ./emit.nix { inherit lib nftlib cfg assembled; };
in {
  config = lib.mkIf cfg.enable (lib.mkMerge [
    emitted
    {
      networking.nftfw._internal.ir = {
        inherit collected validated;
        zones = irZones;
        tables = irTables;
        rules = irRules;
        dispatch = irDispatch;
      };
    }
  ]);
}
