# Stage 10: emit assembled tables to NixOS native nftables options.
#
# - Each table is rendered to full nftables text (add table + add chain +
#   add rule commands) via nftlib.toTextPretty and emitted into
#   networking.nftables.ruleset so the text is passed verbatim to `nft -f`.
#   (networking.nftables.tables wraps content in an extra `table { }` block
#   which is incompatible with the add-command format we generate.)
# - A snapshot of the last emitted table content is also kept in
#   networking.nftables.tables.<name>.content for standalone harness tests
#   (e.g. integration-smoke) that read the raw text without loading it via
#   the NixOS nftables service.
# - objects.ruleset (raw Layer A escape) → appended to networking.nftables.ruleset.
# - Authoritative mode enables nftables, flushes the ruleset on load, and
#   disables the simpler networking.firewall.
{ lib, nftlib, cfg, assembled }:

let
  dsl = nftlib.dsl;

  # Build a dsl.table node from the assembled table body and render it
  # to full nftables text (add table + add chain + add rule commands).
  renderTable = tbl:
    let
      body = removeAttrs tbl [ "family" "name" ];
      tableNode = dsl.table tbl.family tbl.name body;
      rs = dsl.ruleset [ tableNode ];
    in
      nftlib.toTextPretty rs;

  renderedTables = lib.mapAttrs (_: tbl: renderTable tbl) assembled;

  # Concatenate all rendered table texts into a single ruleset blob.
  allTablesText = lib.concatStringsSep "\n" (lib.attrValues renderedTables);

  rulesetExtra =
    if (cfg.objects.ruleset or null) != null
    then nftlib.toText cfg.objects.ruleset
    else "";

  fullRuleset = allTablesText + (lib.optionalString (rulesetExtra != "") ("\n" + rulesetExtra));
in {
  # Emit rendered table text as a raw ruleset so the add-command format is
  # passed verbatim to `nft -f` without an extra table { } wrapper.
  networking.nftables.enable = true;
  networking.nftables.ruleset = fullRuleset;

  # Keep per-table content accessible for standalone harness tests that
  # read the generated text directly (e.g. tests/integration/smoke.nix).
  networking.nftables.tables = lib.mapAttrs (name: text: {
    family = assembled.${name}.family;
    # Mark disabled so NixOS nftables service does not double-emit this table.
    enable = false;
    content = text;
  }) renderedTables;

  # In authoritative mode, default-flush so only our ruleset survives.
  # In cooperative mode, counter NixOS's auto-escalation: NixOS sets
  # flushRuleset = mkDefault true whenever networking.nftables.ruleset is
  # non-empty, which would silently destroy tables contributed by other
  # modules. Force the cooperative default to false; users can still
  # mkForce it on if they really want.
  networking.nftables.flushRuleset =
    if cfg.authoritative
    then lib.mkDefault true
    else lib.mkDefault false;

  networking.firewall.enable = lib.mkIf cfg.authoritative (lib.mkDefault false);
}
