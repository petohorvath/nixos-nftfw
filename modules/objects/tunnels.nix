{ lib }:

{ config, ... }:

let
  inherit (import ./_common.nix { inherit lib; }) commonFields;

  tunnelSubmodule = { name, ... }: {
    options = {
      id = lib.mkOption {
        type = lib.types.int;
        description = "Tunnel id (VXLAN VNI, ERSPAN id, GENEVE VNI).";
      };
      "src-ipv4" = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "IPv4 source endpoint for the tunnel.";
      };
      "dst-ipv4" = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "IPv4 destination endpoint.";
      };
      "src-ipv6" = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "IPv6 source endpoint.";
      };
      "dst-ipv6" = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "IPv6 destination endpoint.";
      };
      sport = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Encapsulating transport source port.";
      };
      dport = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Encapsulating transport destination port.";
      };
      tunnel = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Tunnel-type-specific fields (vxlan/erspan-v1/erspan-v2/geneve sub-record).";
      };
    } // commonFields;
  };
in {
  options.networking.nftfw.objects.tunnels = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule tunnelSubmodule);
    default = { };
    description = "Named tunnel objects (VXLAN, ERSPAN, GENEVE).";
  };
}
