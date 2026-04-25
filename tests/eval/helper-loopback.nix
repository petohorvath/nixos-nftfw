{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  rules = userCfg: (h.evalConfig userCfg).networking.nftfw.rules.filter;
in
  h.runTests {
    testLoopbackPresentInAuthoritative = {
      expr = (rules ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.authoritative = true;
      })) ? _helper-loopback-accept;
      expected = true;
    };

    testLoopbackAbsentInCooperativeByDefault = {
      expr = (rules ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.authoritative = false;
      })) ? _helper-loopback-accept;
      expected = false;
    };

    testLoopbackOptInCooperative = {
      expr = (rules ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.authoritative = false;
        networking.nftfw.helpers.loopbackAccept.enable = true;
      })) ? _helper-loopback-accept;
      expected = true;
    };

    testLoopbackOptOutAuthoritative = {
      expr = (rules ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.authoritative = true;
        networking.nftfw.helpers.loopbackAccept.enable = false;
      })) ? _helper-loopback-accept;
      expected = false;
    };

    testLoopbackVerdictAccept = {
      expr = (rules ({ ... }: {
        networking.nftfw.enable = true;
      }))._helper-loopback-accept.verdict;
      expected = "accept";
    };

    testLoopbackPriorityIs100 = {
      expr = (rules ({ ... }: {
        networking.nftfw.enable = true;
      }))._helper-loopback-accept.priority;
      expected = 100;
    };
  }
