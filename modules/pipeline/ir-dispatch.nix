# Pipeline stage 6: build the dispatch IR.
#
# For each (tableName, chain) pair that has at least one emission, list:
#   - the per-zone subchains needed (one per source zone referenced by
#     a rule in that pair)
#   - the rules in each subchain (filtered to only those whose `from`
#     contains the subchain's zone)
#
# Output is keyed by "<tableName>::<chain>" for stable lookup. The
# rendering layer (Tasks 22-23) will translate this IR into nftypes
# chains and base-chain dispatches.
{ lib, irZones, irRules }:

let
  # Group rules by (tableName, chain).
  groupKey = r: "${r.tableName}::${r.chain}";

  # Collect unique source zones referenced by a list of rules. Excludes
  # the wildcard `any` (which doesn't get its own dispatch chain — those
  # rules render directly in the major chain).
  referencedZones = rules:
    let
      raw = lib.concatMap (r:
        let from = r.rule.from or [ ]; in
        if builtins.isList from then from else [ from ]
      ) rules;
      filtered = lib.filter (z: z != "any" && z != null && irZones ? ${z}) raw;
    in
      lib.unique filtered;

  # Collect rules whose `from` contains a specific zone.
  rulesForZone = zoneName: rules:
    lib.filter (r:
      let from = r.rule.from or [ ]; in
      lib.elem zoneName (if builtins.isList from then from else [ from ])
    ) rules;

  # Rules whose `from` is "any" or empty — render directly in the major
  # chain rather than via a dispatch jump.
  rulesAtMajor = rules:
    lib.filter (r:
      let from = r.rule.from or [ ]; in
      let froms = if builtins.isList from then from else [ from ]; in
      froms == [ ] || lib.any (z: z == "any") froms
    ) rules;

  buildEntry = key: rules:
    let
      parts = lib.splitString "::" key;
      tableName = lib.elemAt parts 0;
      chain = lib.elemAt parts 1;
      zones = referencedZones rules;
    in {
      inherit tableName chain;
      majorRules = rulesAtMajor rules;
      subchains = map (zoneName: {
        inherit zoneName;
        # Per-zone dispatch chain name: "<chain>-from-<zoneName>"
        # e.g. "input-from-wan", "forward-from-lan"
        name = "${chain}-from-${zoneName}";
        rules = rulesForZone zoneName rules;
      }) zones;
    };

  grouped = lib.groupBy groupKey irRules;
in
  lib.mapAttrs buildEntry grouped
