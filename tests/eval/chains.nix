{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  eval = userCfg: (h.evalConfig userCfg).networking.nftfw.objects;
in
  h.runTests {
    testChainBaseDecl = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.chains.my-input = {
          table = "main";
          type = "filter";
          hook = "input";
          priority = 0;
          policy = "drop";
        };
      })).chains.my-input.policy;
      expected = "drop";
    };
    testChainRegular = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.chains.helper = {
          table = "main";
          rules = [ ];
        };
      })).chains.helper.type;
      expected = null;
    };
    testChainRulesPreserved = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.chains.h = {
          table = "main";
          rules = [ { _marker = 1; } { _marker = 2; } ];
        };
      })).chains.h.rules;
      expected = [ { _marker = 1; } { _marker = 2; } ];
    };
    testRulesetOverride = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.ruleset = { nftables = [ ]; };
      })).ruleset;
      expected = { nftables = [ ]; };
    };
    testRulesetDefault = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
      })).ruleset;
      expected = null;
    };
  }
