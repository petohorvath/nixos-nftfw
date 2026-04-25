/*
  Chain submodule (`networking.nftfw.objects.chains.<name>`).

  Declares user-defined base or regular chains inside a named table
  (R4 escape from kind-typed rules). Fields: `table`, `type`, `hook`,
  `priority`, `policy`, `devices`, `comment`, and an ordered `rules`
  list of raw nftypes rule fragments.
*/
{ lib }:

{ ... }:

let
  chainSubmodule = { ... }: {
    options = {
      table = lib.mkOption {
        type = lib.types.str;
        description = "Name of the host table (must reference an entry in `objects.tables`).";
      };
      type = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [ "filter" "nat" "route" ]);
        default = null;
        description = "Base-chain type; null = regular chain (jump/goto target only).";
      };
      hook = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [
          "prerouting" "input" "forward" "output" "postrouting" "ingress" "egress"
        ]);
        default = null;
        description = "Hook this chain attaches to; null for regular chains.";
      };
      priority = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Hook priority; required for base chains.";
      };
      policy = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [ "accept" "drop" ]);
        default = null;
        description = "Default verdict for base chains; null = accept (nftables default).";
      };
      devices = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Interfaces bound (netdev/bridge ingress chains only).";
      };
      comment = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Free-form comment carried into the generated ruleset.";
      };
      rules = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        description = ''
          Ordered rule fragments inside the chain. Each entry shares the
          common rule-fragment shape (matches + statements + verdict).
          List order is preserved as the order of emitted rules; priority
          bands do NOT apply to chain-centric rules.
        '';
      };
    };
  };
in {
  options.networking.nftfw.objects.chains = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule chainSubmodule);
    default = { };
    description = "User-declared base or regular chains (R4 escape from kind-typed rules).";
  };
}
