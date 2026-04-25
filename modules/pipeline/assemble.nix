/*
  Stage 9: assemble each target table as a dsl-compatible table value.

  Combines: chains (base + per-zone subchains), rendered rules in each
  chain, and renderedObjects into a single dsl.table-compatible body
  per table name.

  The output shape per table is:
    { family, name, flags, chains = { <name> = { type, hook, prio, policy,
      rules = [{ expr = [...] }] }; }, sets, maps, counters, quotas,
      limits, flowtables }
*/
{ lib, nftlib, irTables, irRules, irDispatch, renderedObjects, renderRules, cfg }:

let
  # Default base-chain hook & priority assignments for filter chains.
  filterChain = chainName:
    let
      hookName = chainName;
      priority = 0;
      authoritativePolicy = {
        input = "drop";
        forward = "drop";
        output = "accept";
      }.${chainName};
      cooperativePolicy = "accept";
      defaultPolicy =
        if cfg.authoritative then authoritativePolicy else cooperativePolicy;
    in {
      type = "filter";
      hook = hookName;
      prio = priority;
      policy = defaultPolicy;
    };

  natChain = direction:
    let
      hookName =
        if direction == "nat-prerouting" then "prerouting"
        else if direction == "nat-postrouting" then "postrouting"
        else throw "natChain: bad direction '${direction}'";
      priority =
        if direction == "nat-prerouting" then -100 else 100;
    in {
      type = "nat";
      hook = hookName;
      prio = priority;
    };

  mangleChain = direction:
    {
      type = "filter";
      hook =
        if direction == "mangle-prerouting" then "prerouting"
        else throw "mangleChain: bad direction '${direction}'";
      prio = -150;
    };

  baseChainConfig = chainName:
    if lib.elem chainName [ "input" "forward" "output" ]
    then filterChain chainName
    else if lib.elem chainName [ "nat-prerouting" "nat-postrouting" ]
    then natChain chainName
    else if chainName == "mangle-prerouting"
    then mangleChain chainName
    else throw "baseChainConfig: unknown chain '${chainName}'";

  # Render a single rule emission record into a dsl-compatible rule entry
  # (`{ expr = [...statements...]; }`).
  renderRuleRecord = record:
    let stmts = renderRules.render { resolvedRule = record; };
    in { expr = stmts; };

  # For a (table, chain), return the rules ordered: major rules + per-zone
  # subchain rules flattened in zone-name order.
  renderChainRules = tableName: chainName:
    let
      key = "${tableName}::${chainName}";
      entry = irDispatch.${key} or null;
    in
      if entry == null then [ ]
      else
        map renderRuleRecord (
          entry.majorRules
          ++ (lib.concatMap (s: s.rules) entry.subchains)
        );

  # All chains we need to create for a given table (those with at least
  # one rule emission in irDispatch).
  neededChains = tableName:
    let
      fromRules = lib.unique (
        lib.concatMap (key:
          let parts = lib.splitString "::" key; in
          if (lib.elemAt parts 0) == tableName then [ (lib.elemAt parts 1) ]
          else [ ]
        ) (lib.attrNames irDispatch)
      );
    in
      fromRules;

  buildTableChains = tableName:
    let
      chains = neededChains tableName;
    in
      lib.listToAttrs (map (cn: {
        name = cn;
        value = (baseChainConfig cn) // {
          rules = renderChainRules tableName cn;
        };
      }) chains);

  # Filter renderedObjects to those whose targets list contains tableName.
  scopedObjects = tableName: kindMap:
    lib.filterAttrs (_: o: lib.elem tableName o.targets) kindMap;

  buildTableObjects = tableName: {
    sets = lib.mapAttrs (_: o: o.body) (scopedObjects tableName renderedObjects.emitSets);
    maps = lib.mapAttrs (_: o: o.body) (scopedObjects tableName renderedObjects.emitMaps);
    counters = lib.mapAttrs (_: o: o.body) (scopedObjects tableName renderedObjects.emitCounters);
    quotas = lib.mapAttrs (_: o: o.body) (scopedObjects tableName renderedObjects.emitQuotas);
    limits = lib.mapAttrs (_: o: o.body) (scopedObjects tableName renderedObjects.emitLimits);
    flowtables = lib.mapAttrs (_: o: o.body) (scopedObjects tableName renderedObjects.emitFlowtables);
  };

  buildTable = tableName:
    let
      tablePlan = irTables.${tableName};
      chains = buildTableChains tableName;
      objects = buildTableObjects tableName;
      # Only include flags when non-empty; dsl.table passes flags through to
      # the text renderer which produces "flags  " for an empty list.
      tableBase = {
        family = tablePlan.family;
        name = tableName;
        inherit chains;
      };
      flagsAttr = lib.optionalAttrs (tablePlan.flags != [ ]) { flags = tablePlan.flags; };
    in tableBase // flagsAttr
    # Only include non-empty object maps so the dsl.table builder doesn't
    # emit empty `add set` declarations.
    // (lib.optionalAttrs (objects.sets != { }) { inherit (objects) sets; })
    // (lib.optionalAttrs (objects.maps != { }) { inherit (objects) maps; })
    // (lib.optionalAttrs (objects.counters != { }) { inherit (objects) counters; })
    // (lib.optionalAttrs (objects.quotas != { }) { inherit (objects) quotas; })
    // (lib.optionalAttrs (objects.limits != { }) { inherit (objects) limits; })
    // (lib.optionalAttrs (objects.flowtables != { }) { inherit (objects) flowtables; });
in
  lib.mapAttrs (name: _: buildTable name) irTables
