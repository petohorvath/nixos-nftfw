# Stage 10: emit assembled tables to NixOS native nftables options.
#
# - Each table → networking.nftables.tables.<name> with text content
#   produced by nftlib.toText (via dsl.table + dsl.ruleset).
# - The content includes full `add table`, `add chain`, and `add rule`
#   commands so it is directly parseable by `nft -c -f`.
# - objects.ruleset (raw Layer A escape) → networking.nftables.ruleset
#   appended as text.
# - Authoritative mode adds two mkDefault settings.
{ lib, nftlib, cfg, assembled }:

let
  dsl = nftlib.dsl;

  # Build a dsl.table node from the assembled table body and render it
  # to full nftables text (add table + add chain + add rule commands).
  renderTable = tbl:
    let
      # dsl.table takes: family, name, body (all other fields)
      body = removeAttrs tbl [ "family" "name" ];
      tableNode = dsl.table tbl.family tbl.name body;
      rs = dsl.ruleset [ tableNode ];
    in
      nftlib.toTextPretty rs;

  rulesetExtra =
    if (cfg.objects.ruleset or null) != null
    then nftlib.toText cfg.objects.ruleset
    else "";
in {
  networking.nftables.tables = lib.mapAttrs (name: tbl: {
    family = tbl.family;
    content = renderTable tbl;
  }) assembled;

  networking.nftables.ruleset = lib.mkIf (rulesetExtra != "") rulesetExtra;

  networking.nftables.flushRuleset = lib.mkIf cfg.authoritative (lib.mkDefault true);
  networking.firewall.enable = lib.mkIf cfg.authoritative (lib.mkDefault false);
}
