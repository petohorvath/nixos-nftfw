{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };

  result = builtins.tryEval (
    builtins.deepSeq
      (h.evalConfig ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.tunnels.bad = {
          id = 1;
          "src-ipv4" = "not-an-ip";
        };
      })).networking.nftfw.objects.tunnels
      "ok"
  );
in
  pkgs.runCommand "assertion-tunnel-bad-address-fails" { } (
    if result.success
    then ''
      echo 'expected eval failure (libnet should reject "not-an-ip" for tunnel src-ipv4) but got success' >&2
      exit 1
    ''
    else "touch $out"
  )
