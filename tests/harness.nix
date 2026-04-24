{ pkgs, libnet, nftlib }:

let
  inherit (pkgs) lib;

  evalConfig = userConfig: (lib.evalModules {
    modules = [
      (import ../module.nix { inherit lib; inherit nftlib; })
      userConfig
    ];
    specialArgs = { inherit libnet nftlib; };
  }).config;

  runTests = suite:
    let
      results = lib.runTests suite;
    in
      if results == [ ]
      then pkgs.runCommand "tests-ok" { } "touch $out"
      else throw "test failures: ${builtins.toJSON results}";
in
  { inherit evalConfig runTests; }
