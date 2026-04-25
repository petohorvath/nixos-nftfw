{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  irTables = userCfg: (h.evalConfig userCfg).networking.nftfw._internal.ir.tables;
in
  h.runTests {
    testLazyMainOnRules = {
      expr = (irTables ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.rules.filter.r = {
          from = "any"; to = "local"; verdict = "accept";
        };
      })).main.family;
      expected = "inet";
    };
    testLazyMainSynthesizedFlag = {
      expr = (irTables ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.rules.filter.r = {
          from = "any"; to = "local"; verdict = "accept";
        };
      })).main.synthesized;
      expected = true;
    };
    testNoLazyMainWhenUserDeclares = {
      expr = (irTables ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.tables.custom.family = "ip";
        networking.nftfw.rules.filter.r = {
          from = "any"; to = "local"; verdict = "accept";
        };
      })) ? main;
      expected = false;
    };
    testUserTableSynthesizedFalse = {
      expr = (irTables ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.tables.custom.family = "ip";
      })).custom.synthesized;
      expected = false;
    };
    testNoSynthesisWhenNoRules = {
      # In cooperative mode (authoritative = false) the helpers that
      # auto-inject rules in authoritative mode are disabled, so a
      # bare enable = true with no user rules leaves irTables empty.
      expr = (irTables ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.authoritative = false;
      })) == { };
      expected = true;
    };
    testTableFlagsCarried = {
      expr = (irTables ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.tables.dmz = {
          family = "ip"; flags = [ "dormant" ];
        };
      })).dmz.flags;
      expected = [ "dormant" ];
    };
    testNeededBaseChainsEmpty = {
      expr = (irTables ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.tables.custom.family = "ip";
      })).custom.neededBaseChains;
      expected = [ ];
    };
  }
