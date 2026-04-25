/*
  Stateful object submodules: counters, quotas, and limits.

  `objects.counters.<name>` — named packet/byte counters (fields: packets,
  bytes, plus commonFields). `objects.quotas.<name>` — byte quotas (bytes,
  used, inv). `objects.limits.<name>` — rate limits (rate, per, rateUnit,
  burst, burstUnit, inv). All auto-emit to compatible tables.
*/
{ lib }:

{ config, ... }:

let
  inherit (import ./_common.nix { inherit lib; }) commonFields;

  counterSubmodule = { name, ... }: {
    options = {
      packets = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Initial packet count.";
      };
      bytes = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Initial byte count.";
      };
    } // commonFields;
  };

  quotaSubmodule = { name, ... }: {
    options = {
      bytes = lib.mkOption {
        type = lib.types.int;
        description = "Quota size in bytes.";
      };
      used = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Initial bytes-used counter (defaults to 0 in kernel).";
      };
      inv = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Invert — match when the quota is exceeded.";
      };
    } // commonFields;
  };

  limitSubmodule = { name, ... }: {
    options = {
      rate = lib.mkOption {
        type = lib.types.int;
        description = "Rate value.";
      };
      per = lib.mkOption {
        type = lib.types.enum [ "second" "minute" "hour" "day" "week" ];
        description = "Rate time unit.";
      };
      rateUnit = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [ "packets" "bytes" ]);
        default = null;
        description = "Rate quantity unit; null = packets (default).";
      };
      burst = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Burst allowance.";
      };
      burstUnit = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Burst unit for byte-based limits.";
      };
      inv = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Invert — match when the limit is exceeded.";
      };
    } // commonFields;
  };
in {
  options.networking.nftfw.objects.counters = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule counterSubmodule);
    default = { };
    description = "Named counter objects.";
  };
  options.networking.nftfw.objects.quotas = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule quotaSubmodule);
    default = { };
    description = "Named quota objects.";
  };
  options.networking.nftfw.objects.limits = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule limitSubmodule);
    default = { };
    description = "Named limit objects.";
  };
}
