{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };

  result = builtins.tryEval (
    builtins.deepSeq
      (h.evalConfig ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.zones.bad.addresses.ipv4 = [ "999.0.0.1/24" ];
      })).networking.nftfw.zones
      "ok"
  );
in
  pkgs.runCommand "assertion-zone-bad-ipv4-fails" { } (
    if result.success
    then ''
      echo 'expected eval failure (libnet should reject 999.0.0.1/24) but got success' >&2
      exit 1
    ''
    else "touch $out"
  )
