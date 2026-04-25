{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  sysctl = userCfg: (h.evalConfig userCfg).boot.kernel.sysctl;
in
  h.runTests {
    testHardeningOffByDefault = {
      expr = (sysctl ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.authoritative = true;
      })) ? "net.ipv4.conf.all.rp_filter";
      expected = false;
    };
    testHardeningEnabled = {
      expr = (sysctl ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.helpers.kernelHardening.enable = true;
      }))."net.ipv4.conf.all.rp_filter";
      expected = 1;
    };
    testHardeningEnabledIpv6 = {
      expr = (sysctl ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.helpers.kernelHardening.enable = true;
      }))."net.ipv6.conf.all.accept_redirects";
      expected = 0;
    };
  }
