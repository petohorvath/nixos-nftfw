{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };

  result = builtins.tryEval (
    builtins.deepSeq
      (h.evalConfig ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.helpers.stopRuleset.keepAlivePorts = [ 70000 ];
      })).networking.nftfw.helpers.stopRuleset
      "ok"
  );
in
  pkgs.runCommand "assertion-keep-alive-bad-port-fails" { } (
    if result.success
    then ''
      echo 'expected eval failure (libnet should reject port 70000) but got success' >&2
      exit 1
    ''
    else "touch $out"
  )
