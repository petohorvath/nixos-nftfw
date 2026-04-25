/*
  Pipeline stage 1: collect & coerce user-supplied options into the IR.

  Outputs an attrset:
    { zones, nodes, rules, objects }
  where `zones` already includes built-ins (local, any) plus each node
  materialized as a synthetic child zone (`node-<name>` keys).
*/
{ lib, cfg }:

let
  # Materialize each node as a synthetic child zone. Address fields
  # carry the host bits at /32 or /128 so dispatch can match them
  # directly. The `_isNode` and `_nodeName` markers let downstream
  # stages recognize nodes vs. user-declared zones.
  nodeZone = name: node: {
    parent = node.zone;
    interfaces = [ ];
    addresses.ipv4 =
      if node.address.ipv4 != null then [ "${node.address.ipv4}/32" ] else [ ];
    addresses.ipv6 =
      if node.address.ipv6 != null then [ "${node.address.ipv6}/128" ] else [ ];
    conntrackZone = null;
    ingressExpression = null;
    egressExpression = null;
    comment = node.comment;
    _isNode = true;
    _nodeName = name;
  };

  nodesAsZones =
    lib.mapAttrs' (name: node: {
      name = "node-${name}";
      value = nodeZone name node;
    }) cfg.nodes;
in {
  zones = cfg.zones // nodesAsZones;
  nodes = cfg.nodes;
  rules = cfg.rules;
  objects = cfg.objects;
}
