{ lib, nftlib }:

{ config, pkgs, ... }:

{
  imports = [
    (import ./modules/options.nix { inherit lib; })

    # Firewall (Layer B)
    (import ./modules/firewall/zones.nix { inherit lib; })
    (import ./modules/firewall/nodes.nix { inherit lib; })
    (import ./modules/firewall/rules/filter.nix { inherit lib; })
    (import ./modules/firewall/rules/icmp.nix { inherit lib; })
    (import ./modules/firewall/rules/mangle.nix { inherit lib; })
    (import ./modules/firewall/rules/dnat.nix { inherit lib; })
    (import ./modules/firewall/rules/snat.nix { inherit lib; })
    (import ./modules/firewall/rules/redirect.nix { inherit lib; })

    # Objects (Layer A)
    (import ./modules/objects/tables.nix { inherit lib; })
    (import ./modules/objects/chains.nix { inherit lib; })
    (import ./modules/objects/sets.nix { inherit lib; })
    (import ./modules/objects/maps.nix { inherit lib; })
    (import ./modules/objects/stateful.nix { inherit lib; })
    (import ./modules/objects/ct.nix { inherit lib; })
    (import ./modules/objects/flowtables.nix { inherit lib; })
    (import ./modules/objects/secmarks.nix { inherit lib; })
    (import ./modules/objects/synproxies.nix { inherit lib; })
    (import ./modules/objects/tunnels.nix { inherit lib; })
    (import ./modules/objects/ruleset.nix { inherit lib; })

    # Helpers
    (import ./modules/helpers/loopback-accept.nix { inherit lib; })

    # Pipeline
    (import ./modules/pipeline { inherit lib nftlib; })
  ];
}
