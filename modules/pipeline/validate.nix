/*
  Pipeline stage 2: validate references and structural invariants.

  Errors are collected and thrown as a single message so the user sees
  every problem in one pass.
*/
{ lib, collected }:

let
  refs = import ../../lib/refs.nix { inherit lib; };

  zoneNames = lib.attrNames collected.zones;
  nodeNames = lib.attrNames collected.nodes;
  tableNames = lib.attrNames collected.objects.tables;

  # Parent reference check
  invalidParent = lib.concatMap (name:
    let z = collected.zones.${name}; in
    if z.parent != null && !(lib.elem z.parent zoneNames)
    then [ "zone '${name}' has unknown parent '${z.parent}'" ]
    else [ ]) zoneNames;

  # Cyclic parent check
  cyclicDetect = startName:
    let
      go = seen: current:
        if lib.elem current seen
        then [ "zone hierarchy cycle through '${current}'" ]
        else
          let
            zone = collected.zones.${current} or null;
            parent = if zone == null then null else zone.parent;
          in
            if parent == null then [ ]
            else go (seen ++ [ current ]) parent;
    in go [ ] startName;

  cyclicErrors = lib.unique (lib.concatMap cyclicDetect zoneNames);

  # Node zone reference check (a node's zone must exist as a user zone or
  # built-in; built-in zone names like local/any are also valid)
  invalidNodeZone = lib.concatMap (name:
    let n = collected.nodes.${name}; in
    if !(lib.elem n.zone zoneNames)
    then [ "node '${name}' references unknown zone '${n.zone}'" ]
    else [ ]) nodeNames;

  # Zone/node name clash (a node-name is exposed as `node-<name>`, so the
  # raw clash is on the original names — collected.zones hasn't yet been
  # merged with the node-prefixed variants in this check)
  rawZoneNames = lib.attrNames cfg_zones_only_user;
  cfg_zones_only_user = lib.filterAttrs
    (n: _: !(lib.hasPrefix "node-" n))
    collected.zones;
  clash = lib.intersectLists rawZoneNames nodeNames;
  clashErrors = map (n: "name '${n}' used by both zone and node") clash;

  allErrors = invalidParent ++ cyclicErrors ++ invalidNodeZone ++ clashErrors;
  formatted = refs.formatErrors "nftfw: validation failed" allErrors;
in
  if formatted == null
  then null
  else throw formatted
