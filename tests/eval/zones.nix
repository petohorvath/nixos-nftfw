{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };

  withZones = zones: (h.evalConfig ({ ... }: {
    networking.nftfw.enable = true;
    networking.nftfw.zones = zones;
  })).networking.nftfw.zones;
in
  h.runTests {
    testZoneInterfacesOnly = {
      expr = (withZones { wan.interfaces = [ "eth0" ]; }).wan.interfaces;
      expected = [ "eth0" ];
    };
    testZoneWithAddressesV4 = {
      expr = (withZones {
        lan = {
          interfaces = [ "eth1" ];
          addresses.ipv4 = [ "192.168.1.0/24" ];
        };
      }).lan.addresses.ipv4;
      expected = [ "192.168.1.0/24" ];
    };
    testZoneParent = {
      expr = (withZones {
        lan.interfaces = [ "eth1" ];
        trusted.parent = "lan";
      }).trusted.parent;
      expected = "lan";
    };
    testBuiltinLocalZonePresent = {
      expr = (withZones { }) ? local;
      expected = true;
    };
    testBuiltinAnyZonePresent = {
      expr = (withZones { }) ? any;
      expected = true;
    };
  }
