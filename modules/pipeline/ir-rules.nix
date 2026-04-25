/*
  Pipeline stage 5: resolve rule emission.

  For each rule × each applicable table, produce an emission record:
    { kind, name, tableName, chain, family, rule }

  - `chain` is the canonical chain name derived from (kind, from, to):
      filter/icmp:  "input" if to == "local" else "output" if from == "local"
                    else "forward"
      mangle:       "mangle-prerouting"
      dnat/redirect:"nat-prerouting"
      snat:         "nat-postrouting"
  - `family` is the target table's family (the rule will render with
    only the family-applicable subset of any zones it references —
    that family-scoping happens here in stage 5 to a degree, but
    the actual predicate emission per family is in the renderer).
  - NAT kinds are skipped for non-L3 tables (arp, bridge — kind = nat
    only makes sense in ip/ip6/inet).

  Output: a flat list of emission records.
*/
{ lib, collected, irZones, irTables }:

let
  isLocal = name: name == "local";

  pickChain = { kind, from, to }:
    let
      tos = if builtins.isList to then to else (lib.optional (to != null) to);
      froms = if builtins.isList from then from else (lib.optional (from != null) from);
      anyLocalTo = lib.any isLocal tos;
      anyLocalFrom = lib.any isLocal froms;
    in
      if kind == "filter" || kind == "icmp" then
        if anyLocalTo then "input"
        else if anyLocalFrom then "output"
        else "forward"
      else if kind == "mangle" then "mangle-prerouting"
      else if kind == "dnat" || kind == "redirect" then "nat-prerouting"
      else if kind == "snat" then "nat-postrouting"
      else throw "ir-rules: unknown rule kind '${kind}'";

  # Which table families a kind is allowed to emit into.
  kindCompatibleFamilies = kind:
    if kind == "dnat" || kind == "snat" || kind == "redirect"
    then [ "ip" "ip6" "inet" ]
    else if kind == "mangle"
    then [ "ip" "ip6" "inet" "netdev" ]
    else if kind == "icmp"
    then [ "ip" "ip6" "inet" ]
    else [ "ip" "ip6" "inet" "arp" "bridge" "netdev" ];   # filter

  resolveOne = kind: name: rule:
    let
      explicitTables = rule.tables or null;
      compatible = kindCompatibleFamilies kind;

      candidateTables =
        if explicitTables != null
        then lib.filter (t: irTables ? ${t}) explicitTables
        else lib.attrNames irTables;

      emitInto = lib.filter (t: lib.elem irTables.${t}.family compatible) candidateTables;

      chain = pickChain {
        inherit kind;
        from = rule.from or [ ];
        to = rule.to or [ ];
      };
    in
      map (tableName: {
        inherit kind name tableName chain rule;
        family = irTables.${tableName}.family;
      }) emitInto;

  collectKind = kind:
    let kindRules = collected.rules.${kind} or { }; in
    lib.concatMap
      (n: resolveOne kind n kindRules.${n})
      (lib.attrNames kindRules);

in
  lib.concatMap collectKind [ "filter" "icmp" "mangle" "dnat" "snat" "redirect" ]
