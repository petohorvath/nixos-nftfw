{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  rules = userCfg: (h.evalConfig userCfg).networking.nftfw.rules.filter;
in
  h.runTests {
    testRpfilterOffByDefault = {
      expr = (rules ({ ... }: { networking.nftfw.enable = true; })) ? _helper-rpfilter;
      expected = false;
    };
    testRpfilterEnabled = {
      expr = (rules ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.helpers.rpfilter.enable = true;
      })) ? _helper-rpfilter;
      expected = true;
    };
    testRpfilterExemptDefault = {
      expr = (rules ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.helpers.rpfilter.enable = true;
      }))._helper-rpfilter.priority;
      expected = 50;
    };
  }
