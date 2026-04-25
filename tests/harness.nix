{ pkgs, libnet, nftlib }:

let
  inherit (pkgs) lib;

  # Stubs for NixOS options that our module writes into (networking.nftables.*,
  # networking.firewall.enable, boot.kernel.sysctl). These options are provided
  # by the full NixOS module system in production; the standalone harness
  # supplies them here so eval tests work without nixos/modules loaded.
  nixosStubs = { name, ... }: {
    options.networking.nftables = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to enable nftables (stub).";
      };
      flushRuleset = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Flush ruleset on reload (stub).";
      };
      ruleset = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Extra nftables ruleset text (stub).";
      };
      # stopRuleset is declared in modules/options.nix (module-private extension)
      # so we don't redeclare it here to avoid a double-declaration conflict.
      tables = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule (
          { name, ... }: {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Enable this table (stub).";
              };
              name = lib.mkOption {
                type = lib.types.str;
                default = name;
                description = "Table name (stub).";
              };
              family = lib.mkOption {
                type = lib.types.enum [ "ip" "ip6" "inet" "arp" "bridge" "netdev" ];
                description = "Table family (stub).";
              };
              content = lib.mkOption {
                type = lib.types.lines;
                description = "Table content (stub).";
              };
            };
          }
        ));
        default = { };
        description = "Tables (stub).";
      };
    };
    options.networking.firewall = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable simple firewall (stub).";
      };
    };
    options.boot.kernel.sysctl = lib.mkOption {
      type = lib.types.attrsOf lib.types.unspecified;
      default = { };
      description = "Kernel sysctl parameters (stub).";
    };
  };

  evalConfig = userConfig: (lib.evalModules {
    modules = [
      nixosStubs
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
