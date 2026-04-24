{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  eval = userCfg: (h.evalConfig userCfg).networking.nftfw.objects.maps;
in
  h.runTests {
    testMapVerdict = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.maps.dispatch = {
          type = "ifname";
          map = "verdict";
          elements = [ [ "eth0" { jump = { target = "wan-chain"; }; } ] ];
        };
      })).dispatch.map;
      expected = "verdict";
    };
    testMapConcat = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.maps.m = {
          type = [ "ipv4_addr" "inet_service" ];
          map = "ipv4_addr";
        };
      })).m.type;
      expected = [ "ipv4_addr" "inet_service" ];
    };
  }
