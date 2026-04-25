/*
  Build the nftables match expression for a zone's membership in a
  given family and direction.

  When the user has supplied an ingressExpression / egressExpression,
  that expression is the predicate (entire override). Otherwise, build
  an OR of (interface match) ∪ (family-applicable saddr/daddr match).

  The output `_matches` is a list of nftypes match expressions. The
  rendering layer will combine them with OR semantics.
  Returns null if the zone has no membership in this family/direction.
*/
{ lib, nftlib }:

let
  # `family` is the target table family ("ip", "ip6", "inet", "netdev",
  # "bridge", "arp"). `direction` is "ingress" | "egress".
  buildPredicate = { zone, family, direction }:
    let
      override =
        if direction == "ingress" then zone.ingressExpression or null
        else zone.egressExpression or null;
      ifaceField = if direction == "ingress" then "iifname" else "oifname";
      addrField  = if direction == "ingress" then "saddr" else "daddr";

      ifaceMatch = lib.optional (zone.interfaces != [ ]) {
        match = {
          left = { meta = { key = ifaceField; }; };
          right = { set = zone.interfaces; };
          op = "in";
        };
      };

      v4Allowed = lib.elem family [ "ip" "inet" "netdev" "bridge" ];
      v6Allowed = lib.elem family [ "ip6" "inet" "netdev" "bridge" ];

      v4Match = lib.optional (zone.addresses.ipv4 != [ ] && v4Allowed) {
        match = {
          left = { payload = { protocol = "ip"; field = addrField; }; };
          right = { set = zone.addresses.ipv4; };
          op = "in";
        };
      };

      v6Match = lib.optional (zone.addresses.ipv6 != [ ] && v6Allowed) {
        match = {
          left = { payload = { protocol = "ip6"; field = addrField; }; };
          right = { set = zone.addresses.ipv6; };
          op = "in";
        };
      };

      parts = ifaceMatch ++ v4Match ++ v6Match;
    in
      if override != null then { _matches = [ override ]; }
      else if parts == [ ] then null
      else { _matches = parts; };
in {
  ingressPredicate = { zone, family }: buildPredicate { inherit zone family; direction = "ingress"; };
  egressPredicate  = { zone, family }: buildPredicate { inherit zone family; direction = "egress"; };
}
