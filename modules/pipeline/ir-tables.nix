# Pipeline stage 4: build the table plan IR.
#
# Output is an attrset keyed by table name; each entry has:
#   { name, family, flags, synthesized, neededBaseChains }
#
# `main` is lazily synthesized as an inet table iff the user declares
# zero tables AND has at least one rule that needs an emission target.
# `neededBaseChains` is left empty here — populated in stage 5 when rule
# emission is resolved.
{ lib, collected }:

let
  hasAnyRules =
    let
      kindRulesCount = kind:
        lib.length (lib.attrNames (collected.rules.${kind} or { }));
      total = lib.foldl' (acc: kind: acc + kindRulesCount kind) 0
        [ "filter" "icmp" "mangle" "dnat" "snat" "redirect" ];
    in
      total > 0;

  userTables = collected.objects.tables;

  # Synthetic main with all default-shaped fields so downstream stages
  # don't need to special-case its shape.
  syntheticMain = {
    family = "inet";
    flags = [ ];
    comment = null;
    extraContent = null;
    baseChains = {
      input = null;
      forward = null;
      output = null;
      natPrerouting = null;
      natPostrouting = null;
      manglePrerouting = null;
      ingress = null;
      egress = null;
    };
  };

  effective =
    if userTables != { } then userTables
    else if hasAnyRules then { main = syntheticMain; }
    else { };
in
  lib.mapAttrs (name: t: {
    inherit name;
    family = t.family;
    flags = t.flags;
    synthesized = !(userTables ? ${name});
    neededBaseChains = [ ];
  }) effective
