/*
  Stage 8: render named objects (sets, maps, counters, quotas, limits,
  ct.{helpers,timeouts,expectations}, flowtables, secmarks, synproxies,
  tunnels) into nftypes structures, scoped per target table.

  Per-table emission with auto-compatibility checking (set type vs.
  table family) and explicit `tables = [...]` restriction.
*/
{ lib, nftlib, collected, irTables }:

let
  # For ipv4_addr/ipv6_addr typed sets, the families it can live in.
  setFamilyAllowed = setType: tableFamily:
    if setType == "ipv4_addr"
    then lib.elem tableFamily [ "ip" "inet" "netdev" "bridge" ]
    else if setType == "ipv6_addr"
    then lib.elem tableFamily [ "ip6" "inet" "netdev" "bridge" ]
    else true;   # other set types are family-neutral

  # Resolve "auto-emit" vs explicit `tables = [ ... ]` list.
  # Returns the list of table names this object should be emitted into.
  resolveEmissionTables = obj: filterFn:
    let
      explicit = obj.tables or null;
      candidates =
        if explicit != null
        then lib.filter (t: irTables ? ${t}) explicit
        else lib.attrNames irTables;
    in
      lib.filter (t: filterFn irTables.${t}) candidates;

  # Emit each kind of object into per-table buckets. Kept loose
  # (attrs of attrs) for the assembly stage to consume.
  emitSets = lib.mapAttrs' (name: s:
    let setType = if builtins.isList s.type then lib.head s.type else s.type; in {
      inherit name;
      value = {
        targets = resolveEmissionTables s (t: setFamilyAllowed setType t.family);
        body = {
          type = s.type;
          flags = s.flags;
          elem = s.elements;
        }
        // (lib.optionalAttrs (s.timeout != null) { inherit (s) timeout; })
        // (lib.optionalAttrs (s.size != null) { inherit (s) size; });
      };
    }) collected.objects.sets;

  emitMaps = lib.mapAttrs' (name: m: {
    inherit name;
    value = {
      targets = resolveEmissionTables m (_: true);
      body = {
        type = m.type;
        map = m.map;
        flags = m.flags;
      } // (lib.optionalAttrs (m.elements != [ ]) { elem = m.elements; });
    };
  }) collected.objects.maps;

  emitCounters = lib.mapAttrs' (name: c: {
    inherit name;
    value = {
      targets = resolveEmissionTables c (_: true);
      body =
        (lib.optionalAttrs (c.packets != null) { inherit (c) packets; })
        // (lib.optionalAttrs (c.bytes != null) { inherit (c) bytes; });
    };
  }) collected.objects.counters;

  emitQuotas = lib.mapAttrs' (name: q: {
    inherit name;
    value = {
      targets = resolveEmissionTables q (_: true);
      body = {
        bytes = q.bytes;
        inv = q.inv;
      } // (lib.optionalAttrs (q.used != null) { inherit (q) used; });
    };
  }) collected.objects.quotas;

  emitLimits = lib.mapAttrs' (name: l: {
    inherit name;
    value = {
      targets = resolveEmissionTables l (_: true);
      body = {
        rate = l.rate;
        per = l.per;
        inv = l.inv;
      }
      // (lib.optionalAttrs (l.rateUnit != null) { rate_unit = l.rateUnit; })
      // (lib.optionalAttrs (l.burst != null) { inherit (l) burst; })
      // (lib.optionalAttrs (l.burstUnit != null) { burst_unit = l.burstUnit; });
    };
  }) collected.objects.limits;

  emitFlowtables = lib.mapAttrs' (name: f: {
    inherit name;
    value = {
      targets = resolveEmissionTables f (t: lib.elem t.family [ "ip" "ip6" "inet" ]);
      body = {
        hook = f.hook;
        prio = f.priority;
        dev = f.devices;
      };
    };
  }) collected.objects.flowtables;
in {
  inherit emitSets emitMaps emitCounters emitQuotas emitLimits emitFlowtables;
  # ct/secmarks/synproxies/tunnels: stubbed for this commit. Subsequent
  # tasks may extend; their renderers can be added here without touching
  # the assembly stage's contract.
  emitCtHelpers = { };
  emitCtTimeouts = { };
  emitCtExpectations = { };
  emitSecmarks = { };
  emitSynproxies = { };
  emitTunnels = { };
}
