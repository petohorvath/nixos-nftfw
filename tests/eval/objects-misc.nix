{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  eval = userCfg: (h.evalConfig userCfg).networking.nftfw.objects;
in
  h.runTests {
    testFlowtable = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.flowtables.offload = {
          hook = "ingress"; priority = 0;
          devices = [ "eth0" "eth1" ];
        };
      })).flowtables.offload.devices;
      expected = [ "eth0" "eth1" ];
    };
    testSecmark = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.secmarks.trusted = {
          context = "system_u:object_r:firewall_mark_t:s0";
        };
      })).secmarks.trusted.context;
      expected = "system_u:object_r:firewall_mark_t:s0";
    };
    testSynproxy = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.synproxies.shield = {
          mss = 1460; wscale = 7; flags = [ "timestamp" ];
        };
      })).synproxies.shield.mss;
      expected = 1460;
    };
    testTunnelVxlan = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.tunnels.vx0 = {
          id = 42;
          "src-ipv4" = "203.0.113.1";
          "dst-ipv4" = "203.0.114.1";
          sport = 4789;
          dport = 4789;
          tunnel = { gbp = 1; };
        };
      })).tunnels.vx0.id;
      expected = 42;
    };
  }
