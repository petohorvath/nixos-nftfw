{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };

  result = builtins.tryEval (
    builtins.deepSeq
      (h.evalConfig ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.zones.bad.addresses.ipv6 = [ "not-an-ipv6/64" ];
      })).networking.nftfw.zones
      "ok"
  );
in
  pkgs.runCommand "assertion-zone-bad-ipv6-fails" { } (
    if result.success
    then ''
      echo 'expected eval failure (libnet should reject not-an-ipv6/64) but got success' >&2
      exit 1
    ''
    else "touch $out"
  )
