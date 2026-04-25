{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
in
  h.runTests {
    testBundleForceOnInCooperative = {
      expr =
        let cfg = h.evalConfig ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.authoritative = false;
          networking.nftfw.helpers.defaults.enable = true;
        }); in
        cfg.networking.nftfw.helpers.loopbackAccept.enable;
      expected = true;
    };
    testBundleOptOut = {
      expr =
        let cfg = h.evalConfig ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.authoritative = false;
        }); in
        cfg.networking.nftfw.helpers.loopbackAccept.enable;
      expected = false;
    };
  }
