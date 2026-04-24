{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };

  eval = userCfg: (h.evalConfig ({ ... }: {
    networking.nftfw.enable = true;
    networking.nftfw.zones.lan.interfaces = [ "eth1" ];
  } // userCfg)).networking.nftfw.nodes;
in
  h.runTests {
    testNodeV4 = {
      expr = (eval {
        networking.nftfw.nodes.webserver = {
          zone = "lan";
          address.ipv4 = "192.168.1.50";
        };
      }).webserver.address.ipv4;
      expected = "192.168.1.50";
    };
    testNodeDualStack = {
      expr = (eval {
        networking.nftfw.nodes.ws = {
          zone = "lan";
          address.ipv4 = "192.168.1.50";
          address.ipv6 = "fd00::50";
        };
      }).ws.address.ipv6;
      expected = "fd00::50";
    };
    testNodeZoneRequired = {
      expr = (eval {
        networking.nftfw.nodes.n = {
          zone = "lan";
        };
      }).n.zone;
      expected = "lan";
    };
  }
