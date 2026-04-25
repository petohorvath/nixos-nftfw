# Pipeline stage 3: build the zone graph IR.
#
# For each zone (including built-in `local`/`any` and the synthetic
# `node-<name>` zones), compute:
#   - parent (already in collected.zones)
#   - descendants (zones whose parent points back here)
#   - familySet (which nftables families this zone applies to)
#   - predicates: per-family per-direction nftypes match expressions
{ lib, nftlib, collected }:

let
  family = import ../../lib/family.nix { inherit lib; };
  zonePred = import ../../lib/zone-predicate.nix { inherit lib nftlib; };

  zones = collected.zones;
  zoneNames = lib.attrNames zones;

  buildEntry = name:
    let zone = zones.${name}; in
    {
      inherit name;
      parent = zone.parent;
      descendants = lib.filter
        (n: ((zones.${n} or { }).parent or null) == name)
        zoneNames;
      familySet = family.zoneApplicable zone;
      predicates = lib.listToAttrs (map (f: {
        name = f;
        value = {
          ingress = zonePred.ingressPredicate { inherit zone; family = f; };
          egress  = zonePred.egressPredicate  { inherit zone; family = f; };
        };
      }) family.all);
    };
in
  lib.listToAttrs (map (n: { name = n; value = buildEntry n; }) zoneNames)
