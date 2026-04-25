{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };

  cfg = h.evalConfig ({ ... }: {
    networking.nftfw.enable = true;
    networking.nftfw.authoritative = false;     # don't disable firewall during test
    networking.nftfw.rules.filter.allow-ssh = {
      from = "any"; to = "local";
      match.dstPorts.tcp = [ 22 ];
      verdict = "accept";
    };
  });

  generated = cfg.networking.nftables.tables.main.content;
in
  pkgs.runCommand "smoke-nft-parse" {
    nativeBuildInputs = [ pkgs.nftables pkgs.lklWithFirewall ];
  } ''
    set -euo pipefail
    cat <<'EOF' > ruleset.nft
${generated}
EOF
    echo "=== generated ruleset ==="
    cat ruleset.nft
    echo "=== parsing with nft -c ==="
    LD_PRELOAD="${pkgs.lklWithFirewall.lib}/lib/liblkl-hijack.so" \
      nft -c -f ruleset.nft
    echo "=== ok ==="
    touch $out
  ''
