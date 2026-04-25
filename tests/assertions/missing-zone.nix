{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };

  result = builtins.tryEval (
    builtins.deepSeq
      (h.evalConfig ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.nodes.web = {
          zone = "nonexistent";
          address.ipv4 = "10.0.0.1";
        };
      })).networking.nftfw._internal.ir
      "ok"
  );
in
  pkgs.runCommand "assertion-missing-zone-fails" { } (
    if result.success
    then ''
      echo 'expected failure (validation should reject unknown zone reference) but got success' >&2
      exit 1
    ''
    else "touch $out"
  )
