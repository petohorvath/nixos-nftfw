# Pipeline aggregator. Runs each stage in sequence and exposes the
# resulting IR via `networking.nftfw._internal.ir`.
{ lib, nftlib }:

{ config, ... }:

let
  cfg = config.networking.nftfw;
  collected = import ./collect.nix { inherit lib cfg; };
  validated = import ./validate.nix { inherit lib collected; };
  irZones = import ./ir-zones.nix { inherit lib nftlib collected; };
in {
  config.networking.nftfw._internal.ir = lib.mkIf cfg.enable {
    inherit collected validated;
    zones = irZones;
  };
}
