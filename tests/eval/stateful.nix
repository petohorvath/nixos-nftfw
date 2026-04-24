{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  eval = userCfg: (h.evalConfig userCfg).networking.nftfw.objects;
in
  h.runTests {
    testCounterDefaults = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.counters.c1 = { };
      })).counters.c1.packets;
      expected = null;
    };
    testLimitBurst = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.limits.slow = { rate = 5; per = "second"; burst = 10; };
      })).limits.slow.burst;
      expected = 10;
    };
    testQuotaBytes = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.quotas.monthly = { bytes = 1000000000; };
      })).quotas.monthly.bytes;
      expected = 1000000000;
    };
    testCommonTables = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.counters.c = { tables = [ "main" ]; };
      })).counters.c.tables;
      expected = [ "main" ];
    };
  }
