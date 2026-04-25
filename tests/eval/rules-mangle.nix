{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  eval = userCfg: (h.evalConfig userCfg).networking.nftfw.rules.mangle;
in
  h.runTests {
    testMangleSetMark = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.zones.lan.interfaces = [ "eth1" ];
        networking.nftfw.rules.mangle.mark-lan = {
          from = "lan";
          setMark = 42;
        };
      })).mark-lan.setMark;
      expected = 42;
    };
    testMangleSetDscpString = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.zones.lan.interfaces = [ "eth1" ];
        networking.nftfw.rules.mangle.dscp-ef = {
          from = "lan";
          setDscp = "ef";
        };
      })).dscp-ef.setDscp;
      expected = "ef";
    };
    testMangleSetDscpInt = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.rules.mangle.dscp46 = {
          from = "any";
          setDscp = 46;
        };
      })).dscp46.setDscp;
      expected = 46;
    };
    testMangleNoVerdictByDefault = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.rules.mangle.r = {
          from = "any";
          setMark = 1;
        };
      })).r.verdict;
      expected = null;
    };
    testMangleHasNoToField = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.rules.mangle.r = {
          from = "any"; setMark = 1;
        };
      })).r ? to;
      expected = false;
    };
  }
