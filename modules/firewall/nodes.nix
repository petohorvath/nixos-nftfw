/*
  Node submodule (`networking.nftfw.nodes.<name>`).

  A node is a named single host. Fields: `zone` (required — parent zone),
  `address.ipv4`/`.ipv6` (single addresses), and `comment`. The pipeline
  materialises each node as a synthetic child zone (`node-<name>`) at
  /32 or /128, usable wherever a zone name is accepted.
*/
{ lib }:

{ config, libnet, ... }:

let
  nodeSubmodule = { name, ... }: {
    options = {
      zone = lib.mkOption {
        type = lib.types.str;
        description = "Parent zone (required). The node materialises as a synthetic child zone at /32 or /128.";
      };
      address.ipv4 = lib.mkOption {
        type = lib.types.nullOr libnet.types.ipv4;
        default = null;
        description = "Single IPv4 address for this node.";
      };
      address.ipv6 = lib.mkOption {
        type = lib.types.nullOr libnet.types.ipv6;
        default = null;
        description = "Single IPv6 address for this node.";
      };
      comment = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Free-form comment carried into the generated ruleset.";
      };
    };
  };
in {
  options.networking.nftfw.nodes = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule nodeSubmodule);
    default = { };
    description = "Named hosts; usable wherever a zone is.";
  };
}
