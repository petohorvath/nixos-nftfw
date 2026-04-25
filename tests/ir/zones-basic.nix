{ pkgs, libnet, nftlib }:

let
  h = import ../harness.nix { inherit pkgs libnet nftlib; };
  irZones = userCfg: (h.evalConfig userCfg).networking.nftfw._internal.ir.zones;

  inherit (pkgs) lib;
in
  h.runTests {
    testWanFamilySet = {
      expr = (irZones ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.zones.wan.interfaces = [ "eth0" ];
      })).wan.familySet;
      expected = [ "ip" "ip6" "inet" "arp" "bridge" "netdev" ];
    };

    testLanDualStack = {
      expr = lib.sort (a: b: a < b) (irZones ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.zones.lan = {
          interfaces = [ "eth1" ];
          addresses.ipv4 = [ "192.168.1.0/24" ];
          addresses.ipv6 = [ "fd00::/64" ];
        };
      })).lan.familySet;
      expected = [ "bridge" "inet" "ip" "ip6" "netdev" ];
    };

    testV4OnlyZone = {
      expr = lib.sort (a: b: a < b) (irZones ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.zones.dmz = {
          addresses.ipv4 = [ "10.0.0.0/8" ];
        };
      })).dmz.familySet;
      expected = [ "bridge" "inet" "ip" "netdev" ];
    };

    testInetIngressPredicateNonNull = {
      expr = (irZones ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.zones.lan.interfaces = [ "eth1" ];
      })).lan.predicates.inet.ingress != null;
      expected = true;
    };

    testNodeZonePresent = {
      expr = (irZones ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.zones.lan.interfaces = [ "eth1" ];
        networking.nftfw.nodes.web = {
          zone = "lan";
          address.ipv4 = "192.168.1.50";
        };
      })) ? "node-web";
      expected = true;
    };

    testNodeZoneParent = {
      expr = (irZones ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.zones.lan.interfaces = [ "eth1" ];
        networking.nftfw.nodes.web = {
          zone = "lan";
          address.ipv4 = "192.168.1.50";
        };
      }))."node-web".parent;
      expected = "lan";
    };

    testZoneDescendants = {
      expr = lib.sort (a: b: a < b) (irZones ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.zones.lan.interfaces = [ "eth1" ];
        networking.nftfw.zones.trusted.parent = "lan";
        networking.nftfw.zones.dmz.parent = "lan";
      })).lan.descendants;
      expected = [ "dmz" "trusted" ];
    };

    testIngressExpressionOverride = {
      expr = (irZones ({ ... }: {
        networking.nftfw.enable = true;
        networking.nftfw.zones.vpn = {
          ingressExpression = { match = { left = { meta = { key = "mark"; }; }; right = 42; op = "=="; }; };
          egressExpression  = { match = { left = { meta = { key = "mark"; }; }; right = 42; op = "=="; }; };
        };
      })).vpn.familySet;
      expected = [ "ip" "ip6" "inet" "arp" "bridge" "netdev" ];
    };
  }
