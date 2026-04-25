{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  sysctl = userCfg: (h.evalConfig userCfg).boot.kernel.sysctl;
in
  h.runTests {
    testIpForwardingOff = {
      expr = (sysctl ({ ... }: { networking.nftfw.enable = true; })) ? "net.ipv4.ip_forward";
      expected = false;
    };
    testIpv4ForwardingOn = {
      expr = (sysctl ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.helpers.ipForwarding.enable = true;
      }))."net.ipv4.ip_forward";
      expected = 1;
    };
    testIpv6ForwardingOn = {
      expr = (sysctl ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.helpers.ipForwarding.enable = true;
      }))."net.ipv6.conf.all.forwarding";
      expected = 1;
    };
    testIpv4ForwardingOnly = {
      expr =
        let s = sysctl ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.helpers.ipForwarding = {
            enable = true; ipv4 = true; ipv6 = false;
          };
        });
        in (s ? "net.ipv4.ip_forward") && !(s ? "net.ipv6.conf.all.forwarding");
      expected = true;
    };
  }
