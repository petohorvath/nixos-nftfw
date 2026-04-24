{ lib }:

{ config, ... }:

let
  nodeSubmodule = { name, ... }: {
    options = {
      zone = lib.mkOption {
        type = lib.types.str;
        description = "Parent zone (required). The node materialises as a synthetic child zone at /32 or /128.";
      };
      address.ipv4 = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Single IPv4 address for this node.";
      };
      address.ipv6 = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
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
