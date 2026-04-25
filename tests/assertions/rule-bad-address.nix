{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };

  result = builtins.tryEval (
    builtins.deepSeq
      (h.evalConfig ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.rules.filter.r = {
          from = "any"; to = "local";
          match.srcAddresses.ipv4 = [ "300.300.300.300/24" ];
          verdict = "drop";
        };
      })).networking.nftfw.rules.filter
      "ok"
  );
in
  pkgs.runCommand "assertion-rule-bad-address-fails" { } (
    if result.success
    then ''
      echo 'expected eval failure (libnet should reject 300.300.300.300/24) but got success' >&2
      exit 1
    ''
    else "touch $out"
  )
