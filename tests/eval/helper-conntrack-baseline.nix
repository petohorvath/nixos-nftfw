{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  rules = userCfg: (h.evalConfig userCfg).networking.nftfw.rules.filter;
in
  h.runTests {
    testCtBaselineEnabledAuthoritative = {
      expr = (rules ({ ... }: { networking.nftfw.enable = true; })) ? _helper-conntrack-est-rel;
      expected = true;
    };
    testCtBaselineDisabledCooperative = {
      expr = (rules ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.authoritative = false;
      })) ? _helper-conntrack-est-rel;
      expected = false;
    };
    testCtBaselineInvalidDrop = {
      expr = (rules ({ ... }: { networking.nftfw.enable = true; }))._helper-conntrack-invalid.verdict;
      expected = "drop";
    };
  }
