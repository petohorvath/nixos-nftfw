{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  inherit (pkgs) lib;

  irRules = userCfg: (h.evalConfig userCfg).networking.nftfw._internal.ir.rules;

  # Find the first rule by name in the rule list (ignoring helper-injected rules).
  findRule = name: rs: lib.findFirst (r: r.name == name) null rs;
in
  h.runTests {
    testFilterToLocalLandsInInput = {
      # Use authoritative = false so helpers don't inject extra rules that
      # would displace the user rule from lib.head position.
      expr =
        let rs = irRules ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.authoritative = false;
          networking.nftfw.rules.filter.r = {
            from = "any"; to = "local"; verdict = "accept";
          };
        });
        in (lib.head rs).chain;
      expected = "input";
    };

    testFilterFromLocalLandsInOutput = {
      expr =
        let rs = irRules ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.authoritative = false;
          networking.nftfw.rules.filter.r = {
            from = "local"; to = "any"; verdict = "accept";
          };
        });
        in (lib.head rs).chain;
      expected = "output";
    };

    testFilterCrossZoneIsForward = {
      expr =
        let rs = irRules ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.authoritative = false;
          networking.nftfw.zones.wan.interfaces = [ "eth0" ];
          networking.nftfw.zones.lan.interfaces = [ "eth1" ];
          networking.nftfw.rules.filter.fwd = {
            from = "wan"; to = "lan"; verdict = "accept";
          };
        });
        in (lib.head rs).chain;
      expected = "forward";
    };

    testDnatLandsInNatPrerouting = {
      expr =
        let rs = irRules ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.authoritative = false;
          networking.nftfw.zones.wan.interfaces = [ "eth0" ];
          networking.nftfw.rules.dnat.web = {
            from = "wan"; forwardTo = "192.168.1.50:80";
          };
        });
        in (findRule "web" rs).chain;
      expected = "nat-prerouting";
    };

    testSnatLandsInNatPostrouting = {
      expr =
        let rs = irRules ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.authoritative = false;
          networking.nftfw.rules.snat.masq = {
            from = "lan"; to = "wan"; translateTo = null;
          };
        });
        in (findRule "masq" rs).chain;
      expected = "nat-postrouting";
    };

    testMangleLandsInManglePrerouting = {
      expr =
        let rs = irRules ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.authoritative = false;
          networking.nftfw.rules.mangle.m = {
            from = "any"; setMark = 1;
          };
        });
        in (findRule "m" rs).chain;
      expected = "mangle-prerouting";
    };

    testFilterRuleLandsInLazyMain = {
      expr =
        let rs = irRules ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.authoritative = false;
          networking.nftfw.rules.filter.r = {
            from = "any"; to = "local"; verdict = "accept";
          };
        });
        in (lib.head rs).tableName;
      expected = "main";
    };

    testNatSkipsBridgeTable = {
      # In cooperative mode (no helpers), a dnat rule with a missing wan
      # zone emits nothing. With authoritative = false, no helper rules
      # are injected either.
      expr =
        let rs = irRules ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.authoritative = false;
          networking.nftfw.objects.tables.br.family = "bridge";
          networking.nftfw.rules.dnat.d = {
            from = "wan"; forwardTo = "10.0.0.1:80";
          };
        });
        in lib.length rs;
      expected = 0;
    };

    testExplicitTablesRestriction = {
      # Verify that a rule with tables = [ "main" ] is only emitted for
      # the "main" table and not for "extra". Use cooperative mode so
      # helper rules don't add extra table entries.
      expr =
        let rs = irRules ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.authoritative = false;
          networking.nftfw.objects.tables.main.family = "inet";
          networking.nftfw.objects.tables.extra.family = "ip";
          networking.nftfw.rules.filter.r = {
            from = "any"; to = "local";
            tables = [ "main" ];
            verdict = "accept";
          };
        });
        in map (r: r.tableName) rs;
      expected = [ "main" ];
    };

    testFamilyAttachedToRecord = {
      expr =
        let rs = irRules ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.authoritative = false;
          networking.nftfw.objects.tables.main.family = "inet";
          networking.nftfw.rules.filter.r = {
            from = "any"; to = "local"; verdict = "accept";
          };
        });
        in (lib.head rs).family;
      expected = "inet";
    };
  }
