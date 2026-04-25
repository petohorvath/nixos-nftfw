{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  eval = userCfg: (h.evalConfig userCfg).networking.nftfw.rules;
in
  h.runTests {
    testDnatForwardTo = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.zones.wan.interfaces = [ "eth0" ];
        networking.nftfw.rules.dnat.web = {
          from = "wan";
          match.dstPorts.tcp = [ 80 ];
          forwardTo = "192.168.1.50:80";
        };
      })).dnat.web.forwardTo;
      expected = "192.168.1.50:80";
    };
    testDnatNoVerdictField = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.rules.dnat.r = {
          from = "any"; forwardTo = ":8080";
        };
      })).dnat.r ? verdict;
      expected = false;
    };
    testSnatMasquerade = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.zones.wan.interfaces = [ "eth0" ];
        networking.nftfw.zones.lan.interfaces = [ "eth1" ];
        networking.nftfw.rules.snat.masq = {
          from = "lan"; to = "wan";
          translateTo = null;
        };
      })).snat.masq.translateTo;
      expected = null;
    };
    testSnatExplicitTarget = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.rules.snat.s = {
          from = "lan"; to = "wan";
          translateTo = "203.0.113.1";
        };
      })).snat.s.translateTo;
      expected = "203.0.113.1";
    };
    testRedirectPort = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.rules.redirect.dns-cap = {
          from = "lan";
          match.dstPorts.udp = [ 53 ];
          redirectTo = 5353;
        };
      })).redirect.dns-cap.redirectTo;
      expected = 5353;
    };
    testRedirectNoTo = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.rules.redirect.r = {
          from = "any"; redirectTo = 8080;
        };
      })).redirect.r ? to;
      expected = false;
    };
  }
