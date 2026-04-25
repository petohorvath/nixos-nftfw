{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
in
  h.runTests {
    testStopRulesetEmittedInAuthoritative = {
      expr =
        let cfg = h.evalConfig ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.authoritative = true;
        }); in
        cfg.networking.nftables.stopRuleset != "";
      expected = true;
    };

    testStopRulesetEmptyInCooperativeByDefault = {
      expr =
        let cfg = h.evalConfig ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.authoritative = false;
        }); in
        cfg.networking.nftables.stopRuleset;
      expected = "";
    };

    testStopRulesetCustomPorts = {
      expr =
        let cfg = h.evalConfig ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.helpers.stopRuleset.keepAlivePorts = [ 22 2222 ];
        }); in
        builtins.match ".*tcp dport [^;]* 22, 2222 [^;]* accept.*" cfg.networking.nftables.stopRuleset != null;
      expected = true;
    };

    testStopRulesetIncludesLoopbackAndEstablished = {
      expr =
        let cfg = h.evalConfig ({ ... }: {
          networking.nftfw.enable = true;
        }); in
        let text = cfg.networking.nftables.stopRuleset; in
        (builtins.match ".*iifname \"lo\" accept.*" text != null)
        && (builtins.match ".*ct state established,related accept.*" text != null);
      expected = true;
    };

    testStopRulesetOptOut = {
      expr =
        let cfg = h.evalConfig ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.authoritative = true;
          networking.nftfw.helpers.stopRuleset.enable = false;
        }); in
        cfg.networking.nftables.stopRuleset;
      expected = "";
    };
  }
