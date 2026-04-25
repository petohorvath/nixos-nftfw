{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  eval = userCfg: (h.evalConfig userCfg).networking.nftfw.rules.filter;
in
  h.runTests {
    testFilterAccept = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.zones.wan.interfaces = [ "eth0" ];
        networking.nftfw.rules.filter.ssh = {
          from = "wan"; to = "local";
          match.dstPorts.tcp = [ 22 ];
          verdict = "accept";
        };
      })).ssh.verdict;
      expected = "accept";
    };
    testFromCoercedToList = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.zones.wan.interfaces = [ "eth0" ];
        networking.nftfw.rules.filter.r = {
          from = "wan"; to = "local"; verdict = "drop";
        };
      })).r.from;
      expected = [ "wan" ];
    };
    testDefaultVerdictAccept = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.rules.filter.r = {
          from = "any"; to = "local";
          match.ct.state = [ "established" "related" ];
        };
      })).r.verdict;
      expected = "accept";
    };
    testFilterCounterRef = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.rules.filter.r = {
          from = "any"; to = "local";
          counter = "ssh-counter";
        };
      })).r.counter;
      expected = "ssh-counter";
    };
    testFilterMatchSrcSet = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.rules.filter.r = {
          from = "wan"; to = "local";
          match.srcSet = "blocklist";
          verdict = "drop";
        };
      })).r.match.srcSet;
      expected = "blocklist";
    };
  }
