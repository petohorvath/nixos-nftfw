{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };

  result = builtins.tryEval (
    builtins.deepSeq
      (h.evalConfig ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.zones.lan.interfaces = [ "eth1" ];
        networking.nftfw.nodes.bad = {
          zone = "lan";
          address.ipv4 = "not-an-ip";
        };
      })).networking.nftfw.nodes
      "ok"
  );
in
  pkgs.runCommand "assertion-node-bad-address-fails" { } (
    if result.success
    then ''
      echo 'expected eval failure (libnet should reject "not-an-ip") but got success' >&2
      exit 1
    ''
    else "touch $out"
  )
