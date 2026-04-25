# Renderer for `rules.filter` kind.
#
# Input:
#   { resolvedRule, zonePredicates, refs }
# where:
#   - resolvedRule = { kind, name, tableName, chain, family, rule }
#   - zonePredicates is a passthrough for downstream extension; not yet
#     consumed (zone match expressions emerge in stage 9 assembly)
#   - refs is a name-resolution helper passthrough; not yet consumed
#
# Output: list of nftypes statement attrsets that, in order, encode
# matches + statements + verdict for the rule.
{ lib, nftlib }:

{ resolvedRule, zonePredicates ? { }, refs ? { } }:

let
  rule = resolvedRule.rule;
  family = resolvedRule.family;

  m = rule.match or { };
  optional = cond: value: lib.optional cond value;

  # Match expressions — only emit if the corresponding field is non-empty.
  tcpDportMatch = optional ((m.dstPorts or { }).tcp or [ ] != [ ]) {
    match = {
      left = { payload = { protocol = "tcp"; field = "dport"; }; };
      right = { set = m.dstPorts.tcp; };
      op = "in";
    };
  };

  udpDportMatch = optional ((m.dstPorts or { }).udp or [ ] != [ ]) {
    match = {
      left = { payload = { protocol = "udp"; field = "dport"; }; };
      right = { set = m.dstPorts.udp; };
      op = "in";
    };
  };

  tcpSportMatch = optional ((m.srcPorts or { }).tcp or [ ] != [ ]) {
    match = {
      left = { payload = { protocol = "tcp"; field = "sport"; }; };
      right = { set = m.srcPorts.tcp; };
      op = "in";
    };
  };

  udpSportMatch = optional ((m.srcPorts or { }).udp or [ ] != [ ]) {
    match = {
      left = { payload = { protocol = "udp"; field = "sport"; }; };
      right = { set = m.srcPorts.udp; };
      op = "in";
    };
  };

  ctStateMatch = optional ((m.ct or { }).state or [ ] != [ ]) {
    match = {
      left = { ct = { key = "state"; }; };
      right = { set = m.ct.state; };
      op = "in";
    };
  };

  protocolMatch = optional ((m.protocol or null) != null) {
    match = {
      left = { meta = { key = "l4proto"; }; };
      right = m.protocol;
      op = "==";
    };
  };

  srcSetMatch = optional ((m.srcSet or null) != null) {
    match = {
      left = { payload = { protocol = "ip"; field = "saddr"; }; };
      right = "@${m.srcSet}";
      op = "in";
    };
  };

  dstSetMatch = optional ((m.dstSet or null) != null) {
    match = {
      left = { payload = { protocol = "ip"; field = "daddr"; }; };
      right = "@${m.dstSet}";
      op = "in";
    };
  };

  matches =
    tcpDportMatch
    ++ udpDportMatch
    ++ tcpSportMatch
    ++ udpSportMatch
    ++ ctStateMatch
    ++ protocolMatch
    ++ srcSetMatch
    ++ dstSetMatch
    ++ (m.extraMatch or [ ]);

  # Statement renderers — only emit when the field is set.
  counterStmt =
    let c = rule.counter or null; in
    if c == null then [ ]
    else if c == false then [ ]
    else if c == true then [ { counter = null; } ]
    else if builtins.isString c then [ { counter = c; } ]
    else [ { counter = c; } ]; # raw nftypes counter object

  limitStmt =
    let l = rule.limit or null; in
    if l == null then [ ]
    else if builtins.isString l then [ { limit = l; } ]
    else [ { limit = l; } ];

  flowtableStmt = optional ((rule.flowtable or null) != null) {
    flow = { flowtable = "@${rule.flowtable}"; };
  };

  ctHelperStmt = optional ((rule.ctHelper or null) != null) {
    "ct helper" = "@${rule.ctHelper}";
  };

  statements =
    counterStmt
    ++ limitStmt
    ++ flowtableStmt
    ++ ctHelperStmt
    ++ (rule.extraStatements or [ ]);

  # Verdict — one of: accept, drop, reject, continue, return, jump, goto, or null
  verdictStmt =
    if (rule.verdict or null) != null then
      [ { ${rule.verdict} = null; } ]
    else if (rule.jumpTo or null) != null then
      [ { jump = { target = rule.jumpTo; }; } ]
    else if (rule.gotoTo or null) != null then
      [ { goto = { target = rule.gotoTo; }; } ]
    else
      [ ];
in
  matches ++ statements ++ verdictStmt
