{ lib }:

{ config, ... }:

let
  common = (import ./_common.nix { inherit lib; }).commonFields;

  helperSubmodule = { name, ... }: {
    options = {
      type = lib.mkOption {
        type = lib.types.str;
        description = "Conntrack helper type name (e.g. \"ftp\", \"tftp\", \"sip\").";
      };
      protocol = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "L4 protocol the helper applies to (e.g. \"tcp\", \"udp\").";
      };
      l3proto = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "L3 protocol the helper applies to (e.g. \"ip\", \"ip6\").";
      };
    } // common;
  };

  timeoutSubmodule = { name, ... }: {
    options = {
      protocol = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "L4 protocol the timeout applies to.";
      };
      l3proto = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "L3 protocol the timeout applies to.";
      };
      policy = lib.mkOption {
        type = lib.types.attrsOf lib.types.int;
        default = { };
        description = "Per-state timeout values in seconds (e.g. { established = 86400; close_wait = 60; }).";
      };
    } // common;
  };

  expectationSubmodule = { name, ... }: {
    options = {
      l3proto = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "L3 protocol.";
      };
      protocol = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "L4 protocol.";
      };
      dport = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Destination port for the expected connection.";
      };
      timeout = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Expectation timeout in milliseconds.";
      };
      size = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Maximum number of concurrent expectations.";
      };
    } // common;
  };
in {
  options.networking.nftfw.objects.ct.helpers = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule helperSubmodule);
    default = { };
    description = "Named conntrack helper objects.";
  };
  options.networking.nftfw.objects.ct.timeouts = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule timeoutSubmodule);
    default = { };
    description = "Named conntrack timeout policy objects.";
  };
  options.networking.nftfw.objects.ct.expectations = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule expectationSubmodule);
    default = { };
    description = "Named conntrack expectation objects.";
  };
}
