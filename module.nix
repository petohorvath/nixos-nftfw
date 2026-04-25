/*
  Top-level NixOS module for nixos-nftfw.

  Receives `lib`, `nftlib`, and `libnet` at import time, threads them
  into _module.args so every submodule can access them as plain
  function arguments, and aggregates all submodules (firewall,
  objects, helpers, pipeline) via `imports`.
*/
{ lib, nftlib, libnet }:

{ config, pkgs, ... }:

let
  libnetTyped = libnet.withLib lib;
in {
  _module.args.libnet = libnetTyped;
  _module.args.nftlib = nftlib;

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
    (import ./modules/helpers/stop-ruleset.nix { inherit lib; })
    (import ./modules/helpers/kernel-hardening.nix { inherit lib; })
    (import ./modules/helpers/conntrack-baseline.nix { inherit lib; })
    (import ./modules/helpers/rpfilter.nix { inherit lib; })
    (import ./modules/helpers/flow-offload.nix { inherit lib; })
    (import ./modules/helpers/ip-forwarding.nix { inherit lib; })
    (import ./modules/helpers/defaults.nix { inherit lib; })

    # Pipeline
    (import ./modules/pipeline { inherit lib nftlib; })
  ];
}
