{ lib }:

{ config, ... }:

{
  options.networking.nftfw = {
    enable = lib.mkEnableOption "nftfw firewall module";

    authoritative = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When true, the module owns the kernel firewall: flushes the
        ruleset at load and disables networking.firewall. When false,
        coexists with other nftables contributors.
      '';
    };

    _internal.ir = lib.mkOption {
      type = lib.types.attrs;
      internal = true;
      readOnly = true;
      description = "Computed IR for debugging. TODO: remove once stable.";
    };
  };

  # Declare the NixOS nftables options that emit.nix writes into, so the
  # module can be evaluated standalone (without the full NixOS module set).
  # When composed with NixOS these declarations are merged with the real
  # options from nixos/modules/services/networking/nftables.nix.
  options.networking.nftables = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable nftables.";
    };

    flushRuleset = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Flush the entire ruleset on each reload.";
    };

    ruleset = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra nftables ruleset text.";
    };

    stopRuleset = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "nftables ruleset loaded by nftables.service on stop.";
    };

    tables = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule (
        { name, ... }: {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              default = name;
              description = "Table name.";
            };
            family = lib.mkOption {
              type = lib.types.enum [ "ip" "ip6" "inet" "arp" "bridge" "netdev" ];
              description = "Table family.";
            };
            content = lib.mkOption {
              type = lib.types.lines;
              description = "The table content (full nft commands).";
            };
          };
        }
      ));
      default = { };
      description = "Tables to emit.";
    };
  };

  options.networking.firewall = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable the simple stateful NixOS firewall.";
    };
  };
}
