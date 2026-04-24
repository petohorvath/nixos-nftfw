{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  eval = userCfg: (h.evalConfig userCfg).networking.nftfw.objects.tables;
in
  h.runTests {
    testTableInet = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.tables.main.family = "inet";
      })).main.family;
      expected = "inet";
    };
    testTableFlags = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.tables.dmz = {
          family = "ip"; flags = [ "dormant" ];
        };
      })).dmz.flags;
      expected = [ "dormant" ];
    };
    testBaseChainPolicy = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.tables.main = {
          family = "inet";
          baseChains.input = { priority = 0; policy = "drop"; };
        };
      })).main.baseChains.input.policy;
      expected = "drop";
    };
    testNetdevIngressDevices = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.tables.ingress = {
          family = "netdev";
          baseChains.ingress = { priority = 0; devices = [ "eth0" ]; };
        };
      })).ingress.baseChains.ingress.devices;
      expected = [ "eth0" ];
    };
  }
