{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };

  result = builtins.tryEval (
    builtins.deepSeq
      (h.evalConfig ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.rules.filter.r = {
          from = "any"; to = "local";
          match.dstPorts.tcp = [ 99999 ];   # > 65535
          verdict = "accept";
        };
      })).networking.nftfw.rules.filter
      "ok"
  );
in
  pkgs.runCommand "assertion-rule-bad-port-fails" { } (
    if result.success
    then ''
      echo 'expected eval failure (libnet should reject port 99999) but got success' >&2
      exit 1
    ''
    else "touch $out"
  )
