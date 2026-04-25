{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  eval = userCfg: (h.evalConfig userCfg).networking.nftfw.rules.icmp;
in
  h.runTests {
    testIcmpV4Types = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.rules.icmp.essentials = {
          from = "any"; to = "local";
          icmp.v4Types = [ "echo-request" "destination-unreachable" ];
          verdict = "accept";
        };
      })).essentials.icmp.v4Types;
      expected = [ "echo-request" "destination-unreachable" ];
    };
    testIcmpV6Types = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.rules.icmp.nd = {
          from = "any"; to = "local";
          icmp.v6Types = [ "nd-neighbor-solicit" "nd-neighbor-advert" ];
        };
      })).nd.icmp.v6Types;
      expected = [ "nd-neighbor-solicit" "nd-neighbor-advert" ];
    };
    testIcmpDualStack = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.rules.icmp.both = {
          from = "any"; to = "local";
          icmp.v4Types = [ "echo-request" ];
          icmp.v6Types = [ "echo-request" ];
        };
      })).both.icmp;
      expected = { v4Types = [ "echo-request" ]; v6Types = [ "echo-request" ]; };
    };
    testIcmpDefaultVerdict = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.rules.icmp.r = {
          from = "any"; to = "local";
          icmp.v4Types = [ "echo-request" ];
        };
      })).r.verdict;
      expected = "accept";
    };
  }
