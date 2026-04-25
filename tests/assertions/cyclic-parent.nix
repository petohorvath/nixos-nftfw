{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };

  result = builtins.tryEval (
    builtins.deepSeq
      (h.evalConfig ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.zones.a.parent = "b";
        networking.nftfw.zones.b.parent = "a";
      })).networking.nftfw._internal.ir
      "ok"
  );
in
  pkgs.runCommand "assertion-cyclic-parent-fails" { } (
    if result.success
    then ''
      echo 'expected failure (validation should reject cyclic zone hierarchy) but got success' >&2
      exit 1
    ''
    else "touch $out"
  )
