# Family compatibility tables. Used by stage 3 (zone applicable-family
# computation) and stage 4 (table emission target derivation).
{ lib }:

rec {
  # Every nftables family.
  all = [ "ip" "ip6" "inet" "arp" "bridge" "netdev" ];

  # Layer-3 families (where ip/ip6 saddr/daddr matches make sense).
  l3 = [ "ip" "ip6" "inet" "netdev" "bridge" ];

  # Compute the families a zone applies to, given its declaration.
  # Rules:
  #   - ingressExpression set → user-asserted; applies to every family
  #   - interfaces only → family-agnostic (iifname/oifname is universal)
  #   - addresses.ipv4 only → ipv4-applicable (ip/inet/netdev/bridge)
  #   - addresses.ipv6 only → ipv6-applicable (ip6/inet/netdev/bridge)
  #   - both address lists → dual-stack (union of v4-applicable and v6-applicable)
  zoneApplicable = zone:
    let
      hasIface = zone.interfaces != [ ];
      hasV4    = zone.addresses.ipv4 != [ ];
      hasV6    = zone.addresses.ipv6 != [ ];
      hasExpr  = (zone.ingressExpression or null) != null
              || (zone.egressExpression or null) != null;

      v4Families = [ "ip" "inet" "netdev" "bridge" ];
      v6Families = [ "ip6" "inet" "netdev" "bridge" ];
    in
      if hasExpr then all
      else if hasIface && !hasV4 && !hasV6 then all
      else lib.unique (
        (lib.optionals hasV4 v4Families)
        ++ (lib.optionals hasV6 v6Families)
        ++ (lib.optionals hasIface (lib.unique (v4Families ++ v6Families)))
      );
}
