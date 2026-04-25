{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  inherit (pkgs) lib;

  irDispatch = userCfg: (h.evalConfig userCfg).networking.nftfw._internal.ir.dispatch;
in
  h.runTests {
    testZoneSubchainCreated = {
      expr =
        let d = irDispatch ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.zones.wan.interfaces = [ "eth0" ];
          networking.nftfw.rules.filter.r = {
            from = "wan"; to = "local"; verdict = "accept";
          };
        });
        in lib.any (g:
          lib.any (s: s.zoneName == "wan") g.subchains
        ) (lib.attrValues d);
      expected = true;
    };

    testSubchainName = {
      expr =
        let d = irDispatch ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.zones.wan.interfaces = [ "eth0" ];
          networking.nftfw.rules.filter.r = {
            from = "wan"; to = "local"; verdict = "accept";
          };
        });
        in
        let entry = lib.head (lib.attrValues d); in
        (lib.head entry.subchains).name;
      expected = "input-from-wan";
    };

    testAnyZoneRendersAtMajor = {
      expr =
        let d = irDispatch ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.rules.filter.r = {
            from = "any"; to = "local"; verdict = "accept";
          };
        });
        in
        let entry = lib.head (lib.attrValues d); in
        lib.length entry.majorRules;
      expected = 1;
    };

    testAnyZoneNoSubchain = {
      expr =
        let d = irDispatch ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.rules.filter.r = {
            from = "any"; to = "local"; verdict = "accept";
          };
        });
        in
        let entry = lib.head (lib.attrValues d); in
        entry.subchains;
      expected = [ ];
    };

    testMultiZoneRulesGroupedSeparately = {
      expr =
        let d = irDispatch ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.zones.wan.interfaces = [ "eth0" ];
          networking.nftfw.zones.lan.interfaces = [ "eth1" ];
          networking.nftfw.rules.filter.r-wan = {
            from = "wan"; to = "local"; verdict = "accept";
          };
          networking.nftfw.rules.filter.r-lan = {
            from = "lan"; to = "local"; verdict = "accept";
          };
        });
        in
        let entry = lib.head (lib.attrValues d); in
        lib.length entry.subchains;
      expected = 2;
    };

    testKeyShape = {
      expr =
        let d = irDispatch ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.rules.filter.r = {
            from = "any"; to = "local"; verdict = "accept";
          };
        });
        in lib.attrNames d;
      expected = [ "main::input" ];
    };

    testForwardChainGrouping = {
      expr =
        let d = irDispatch ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.zones.wan.interfaces = [ "eth0" ];
          networking.nftfw.zones.lan.interfaces = [ "eth1" ];
          networking.nftfw.rules.filter.f1 = {
            from = "wan"; to = "lan"; verdict = "accept";
          };
        });
        in lib.attrNames d;
      expected = [ "main::forward" ];
    };
  }
