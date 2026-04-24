{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  eval = userCfg: (h.evalConfig userCfg).networking.nftfw.objects.ct;
in
  h.runTests {
    testCtHelper = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.ct.helpers.ftp = {
          type = "ftp"; protocol = "tcp"; l3proto = "ip";
        };
      })).helpers.ftp.type;
      expected = "ftp";
    };
    testCtTimeout = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.ct.timeouts.tcp-long = {
          protocol = "tcp"; l3proto = "ip";
          policy = { established = 86400; };
        };
      })).timeouts.tcp-long.policy.established;
      expected = 86400;
    };
    testCtExpectation = {
      expr = (eval ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.objects.ct.expectations.tftp = {
          l3proto = "ip"; protocol = "udp"; dport = 69; timeout = 5000;
        };
      })).expectations.tftp.dport;
      expected = 69;
    };
  }
