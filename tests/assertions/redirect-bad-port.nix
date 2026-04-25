{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };

  result = builtins.tryEval (
    builtins.deepSeq
      (h.evalConfig ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.rules.redirect.r = {
          from = "any";
          redirectTo = 99999;   # > 65535
        };
      })).networking.nftfw.rules.redirect
      "ok"
  );
in
  pkgs.runCommand "assertion-redirect-bad-port-fails" { } (
    if result.success
    then ''
      echo 'expected eval failure (libnet should reject port 99999) but got success' >&2
      exit 1
    ''
    else "touch $out"
  )
