{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  cfg = h.evalConfig ({ ... }: { });
  nftfw = cfg.networking.nftfw;
in
  h.runTests {
    testZonesHasLocal    = { expr = nftfw.zones ? local; expected = true; };
    testZonesHasAny      = { expr = nftfw.zones ? any;   expected = true; };
    testNodesEmpty       = { expr = nftfw.nodes; expected = { }; };
    testRulesFilterEmpty = { expr = nftfw.rules.filter; expected = { }; };
    testRulesIcmpEmpty   = { expr = nftfw.rules.icmp; expected = { }; };
    testRulesMangleEmpty = { expr = nftfw.rules.mangle; expected = { }; };
    testRulesDnatEmpty   = { expr = nftfw.rules.dnat; expected = { }; };
    testRulesSnatEmpty   = { expr = nftfw.rules.snat; expected = { }; };
    testRulesRedirectEmpty = { expr = nftfw.rules.redirect; expected = { }; };
    testObjectsTables    = { expr = nftfw.objects.tables; expected = { }; };
    testObjectsChains    = { expr = nftfw.objects.chains; expected = { }; };
    testObjectsSets      = { expr = nftfw.objects.sets; expected = { }; };
    testObjectsMaps      = { expr = nftfw.objects.maps; expected = { }; };
    testObjectsCounters  = { expr = nftfw.objects.counters; expected = { }; };
    testObjectsQuotas    = { expr = nftfw.objects.quotas; expected = { }; };
    testObjectsLimits    = { expr = nftfw.objects.limits; expected = { }; };
    testObjectsCtHelpers     = { expr = nftfw.objects.ct.helpers; expected = { }; };
    testObjectsCtTimeouts    = { expr = nftfw.objects.ct.timeouts; expected = { }; };
    testObjectsCtExpectations = { expr = nftfw.objects.ct.expectations; expected = { }; };
    testObjectsFlowtables    = { expr = nftfw.objects.flowtables; expected = { }; };
    testObjectsSecmarks      = { expr = nftfw.objects.secmarks; expected = { }; };
    testObjectsSynproxies    = { expr = nftfw.objects.synproxies; expected = { }; };
    testObjectsTunnels       = { expr = nftfw.objects.tunnels; expected = { }; };
    testObjectsRuleset       = { expr = nftfw.objects.ruleset; expected = null; };
  }
