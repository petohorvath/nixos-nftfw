{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
in
  h.runTests {
    testEnableDefault = {
      expr = (h.evalConfig ({ ... }: { })).networking.nftfw.enable;
      expected = false;
    };
    testAuthoritativeDefault = {
      expr = (h.evalConfig ({ ... }: { networking.nftfw.enable = true; }))
             .networking.nftfw.authoritative;
      expected = true;
    };
    testAuthoritativeOverride = {
      expr = (h.evalConfig ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.authoritative = false;
      })).networking.nftfw.authoritative;
      expected = false;
    };
  }
