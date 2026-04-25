/*
  Tunnel submodule (`networking.nftfw.objects.tunnels.<name>`).

  Named tunnel objects for VXLAN, ERSPAN, and GENEVE encapsulation
  matching. Fields: `id`, `src-ipv4`/`dst-ipv4`/`src-ipv6`/`dst-ipv6`,
  `sport`/`dport`, and a `tunnel` attrset for type-specific fields,
  plus the shared `tables`/`comment` from commonFields.
*/
{ lib }:

{ libnet, ... }:

let
  inherit (import ./_common.nix { inherit lib; }) commonFields;

  tunnelSubmodule = { ... }: {
    options = {
      id = lib.mkOption {
        type = lib.types.int;
        description = "Tunnel id (VXLAN VNI, ERSPAN id, GENEVE VNI).";
      };
      "src-ipv4" = lib.mkOption {
        type = lib.types.nullOr libnet.types.ipv4;
        default = null;
        description = "IPv4 source endpoint for the tunnel.";
      };
      "dst-ipv4" = lib.mkOption {
        type = lib.types.nullOr libnet.types.ipv4;
        default = null;
        description = "IPv4 destination endpoint.";
      };
      "src-ipv6" = lib.mkOption {
        type = lib.types.nullOr libnet.types.ipv6;
        default = null;
        description = "IPv6 source endpoint.";
      };
      "dst-ipv6" = lib.mkOption {
        type = lib.types.nullOr libnet.types.ipv6;
        default = null;
        description = "IPv6 destination endpoint.";
      };
      sport = lib.mkOption {
        type = lib.types.nullOr libnet.types.port;
        default = null;
        description = "Encapsulating transport source port.";
      };
      dport = lib.mkOption {
        type = lib.types.nullOr libnet.types.port;
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
