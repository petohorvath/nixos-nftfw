# Shared rule-field types for kind-typed rule submodules and chain-centric
# rule fragments.
#
# This file declares NO options of its own — it returns an attrset of
# field groups that rule-kind submodules (Tasks 13-16) compose into their
# own option sets.
#
# Three composition aliases:
#   - matchSubmodule  : the `match` field's submodule type
#   - statementFields : counter/log/limit/quota/...; merged into rule options
#   - verdictFields   : verdict/jumpTo/gotoTo
#   - dispatchFields  : from/to/tables (only used by kind-typed rules, not by
#                       chain-centric fragments)
#   - coreFields      : enable/comment/priority/match + statements + verdicts
#   - ruleCoreFields  : coreFields + dispatchFields (for kind-typed rules)
#   - ruleFragmentFields : coreFields (for chain-centric rule fragments)
{ lib, libnet }:

rec {
  matchSubmodule = { ... }: {
    options = {
      srcAddresses.ipv4 = lib.mkOption {
        type = lib.types.listOf libnet.types.ipv4Cidr;
        default = [ ];
        description = "IPv4 source addresses or CIDR blocks to match.";
      };
      srcAddresses.ipv6 = lib.mkOption {
        type = lib.types.listOf libnet.types.ipv6Cidr;
        default = [ ];
        description = "IPv6 source addresses or CIDR blocks to match.";
      };
      dstAddresses.ipv4 = lib.mkOption {
        type = lib.types.listOf libnet.types.ipv4Cidr;
        default = [ ];
        description = "IPv4 destination addresses or CIDR blocks to match.";
      };
      dstAddresses.ipv6 = lib.mkOption {
        type = lib.types.listOf libnet.types.ipv6Cidr;
        default = [ ];
        description = "IPv6 destination addresses or CIDR blocks to match.";
      };
      srcSet = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Name of an `objects.sets.<name>` to match against the source address.";
      };
      dstSet = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Name of an `objects.sets.<name>` to match against the destination address.";
      };
      srcPorts.tcp = lib.mkOption {
        type = lib.types.listOf (lib.types.either libnet.types.port libnet.types.portRange);
        default = [ ];
        description = "TCP source ports or port ranges to match.";
      };
      srcPorts.udp = lib.mkOption {
        type = lib.types.listOf (lib.types.either libnet.types.port libnet.types.portRange);
        default = [ ];
        description = "UDP source ports or port ranges to match.";
      };
      dstPorts.tcp = lib.mkOption {
        type = lib.types.listOf (lib.types.either libnet.types.port libnet.types.portRange);
        default = [ ];
        description = "TCP destination ports or port ranges to match.";
      };
      dstPorts.udp = lib.mkOption {
        type = lib.types.listOf (lib.types.either libnet.types.port libnet.types.portRange);
        default = [ ];
        description = "UDP destination ports or port ranges to match.";
      };
      protocol = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Raw L4 protocol name (e.g. \"gre\", \"sctp\", \"icmp\").";
      };
      tcpFlags = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Raw nftables tcp-flags expression (e.g. \"syn / syn,ack\").";
      };
      ct.state = lib.mkOption {
        type = lib.types.listOf (lib.types.enum [ "new" "established" "related" "invalid" "untracked" ]);
        default = [ ];
        description = "Conntrack states to match.";
      };
      ct.direction = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [ "original" "reply" ]);
        default = null;
        description = "Conntrack direction filter.";
      };
      mark = lib.mkOption {
        type = lib.types.nullOr (lib.types.oneOf [ lib.types.int lib.types.str ]);
        default = null;
        description = "Match nftables fwmark (int or string).";
      };
      extraMatch = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        description = "Raw nftypes match expressions appended verbatim.";
      };
    };
  };

  statementFields = {
    counter = lib.mkOption {
      type = lib.types.nullOr (lib.types.oneOf [ lib.types.bool lib.types.str lib.types.attrs ]);
      default = null;
      description = ''
        Attach a counter. Either:
          - true       : auto-create an anonymous counter,
          - "name"     : reference `objects.counters.<name>`,
          - { ... }    : raw nftypes counter object.
      '';
    };
    log = lib.mkOption {
      type = lib.types.nullOr (lib.types.oneOf [ lib.types.bool lib.types.attrs ]);
      default = null;
      description = "Log statement: bool (auto) or { prefix?, level?, group?, flags? }.";
    };
    limit = lib.mkOption {
      type = lib.types.nullOr (lib.types.oneOf [ lib.types.str lib.types.attrs ]);
      default = null;
      description = "Rate limit: \"name\" reference or inline { rate, per, burst?, rateUnit? }.";
    };
    quota = lib.mkOption {
      type = lib.types.nullOr (lib.types.oneOf [ lib.types.str lib.types.attrs ]);
      default = null;
      description = "Quota: \"name\" reference or inline { bytes, ... }.";
    };
    ctHelper = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Reference to `objects.ct.helpers.<name>`.";
    };
    ctTimeout = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Reference to `objects.ct.timeouts.<name>`.";
    };
    ctExpectation = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Reference to `objects.ct.expectations.<name>`.";
    };
    synproxy = lib.mkOption {
      type = lib.types.nullOr (lib.types.oneOf [ lib.types.str lib.types.attrs ]);
      default = null;
      description = "Synproxy: name reference or inline { mss, wscale, flags? }.";
    };
    secmark = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Reference to `objects.secmarks.<name>`.";
    };
    flowtable = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Reference to `objects.flowtables.<name>`; enrols matching traffic.";
    };
    tunnel = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Reference to `objects.tunnels.<name>`.";
    };
    meter = lib.mkOption {
      type = lib.types.nullOr lib.types.attrs;
      default = null;
      description = "Per-source rate meter: { key, stmt, size?, name? }.";
    };
    connectionLimit = lib.mkOption {
      type = lib.types.nullOr lib.types.attrs;
      default = null;
      description = "Per-source connection cap: { count, inv? }.";
    };
    extraStatements = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      description = "Raw nftypes statement objects appended verbatim.";
    };
  };

  verdictFields = {
    verdict = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "accept" "drop" "reject" "continue" "return" ]);
      default = null;
      description = "Terminal verdict; mutually exclusive with jumpTo/gotoTo.";
    };
    jumpTo = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Jump to a chain by name; mutually exclusive with verdict/gotoTo.";
    };
    gotoTo = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Goto a chain by name; mutually exclusive with verdict/jumpTo.";
    };
  };

  dispatchFields = {
    from = lib.mkOption {
      type = lib.types.either lib.types.str (lib.types.listOf lib.types.str);
      default = [ ];
      apply = v: if builtins.isString v then [ v ] else v;
      description = "Source zone(s) or node(s); bare string is coerced to a singleton list.";
    };
    to = lib.mkOption {
      type = lib.types.either lib.types.str (lib.types.listOf lib.types.str);
      default = [ ];
      apply = v: if builtins.isString v then [ v ] else v;
      description = "Destination zone(s) or node(s); bare string is coerced to a singleton list.";
    };
    tables = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      description = ''
        Emission scope. null = auto-emit to every compatible table;
        list = explicit restriction to named tables.
      '';
    };
  };

  coreFields = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether the rule is emitted.";
    };
    comment = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Free-form comment carried into the generated rule.";
    };
    priority = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Position within the dispatched chain's priority bands; null = default (500).";
    };
    match = lib.mkOption {
      type = lib.types.submodule matchSubmodule;
      default = { };
      description = "Match conditions for this rule.";
    };
  } // statementFields // verdictFields;

  ruleCoreFields = coreFields // dispatchFields;
  ruleFragmentFields = coreFields;
}
