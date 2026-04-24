{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  eval = userCfg: (h.evalConfig userCfg).networking.nftfw.objects.sets;
in
  h.runTests {
    testSetBasic = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.sets.bl = {
          type = "ipv4_addr";
          flags = [ "interval" ];
          elements = [ "198.51.100.0/24" ];
        };
      })).bl.type;
      expected = "ipv4_addr";
    };
    testSetTables = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.sets.bl = {
          type = "ipv4_addr";
          tables = [ "main" ];
        };
      })).bl.tables;
      expected = [ "main" ];
    };
    testSetConcatType = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.sets.cat = {
          type = [ "ipv4_addr" "inet_service" ];
        };
      })).cat.type;
      expected = [ "ipv4_addr" "inet_service" ];
    };
  }
