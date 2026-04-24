{ lib, nftlib }:

{ config, pkgs, ... }:

{
  imports = [
    (import ./modules/options.nix { inherit lib; })
  ];
}
