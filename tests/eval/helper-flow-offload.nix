{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
in
  h.runTests {
    testFlowOffloadOffByDefault = {
      expr =
        let cfg = h.evalConfig ({ ... }: { networking.nftfw.enable = true; }); in
        cfg.networking.nftfw.objects.flowtables ? offload;
      expected = false;
    };
    testFlowOffloadCreatesFlowtable = {
      expr =
        let cfg = h.evalConfig ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.helpers.flowOffload = {
            enable = true;
            interfaces = [ "eth0" ];
          };
        }); in
        cfg.networking.nftfw.objects.flowtables.offload.devices;
      expected = [ "eth0" ];
    };
    testFlowOffloadAddsRule = {
      expr =
        let cfg = h.evalConfig ({ ... }: {
          networking.nftfw.enable = true;
          networking.nftfw.helpers.flowOffload = {
            enable = true;
            interfaces = [ "eth0" ];
          };
        }); in
        cfg.networking.nftfw.rules.filter ? _helper-flow-offload;
      expected = true;
    };
  }
