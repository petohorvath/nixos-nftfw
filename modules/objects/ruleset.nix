/*
  Raw ruleset escape (`networking.nftfw.objects.ruleset`).

  Accepts a raw nftypes ruleset value; its rendered text is appended
  verbatim to `networking.nftables.ruleset` alongside the per-table
  content the pipeline generates. Use for constructs the module does
  not model or to take full authorship of the ruleset.
*/
{ lib }:

{ ... }:

{
  options.networking.nftfw.objects.ruleset = lib.mkOption {
    type = lib.types.nullOr lib.types.attrs;
    default = null;
    description = ''
      Raw nftypes ruleset value. When set, its rendered text is
      appended to networking.nftables.ruleset alongside the per-table
      content the module generates. Useful for nftables constructs
      the module does not model (e.g. a hand-authored
      `table netdev ingress-extra { ... }`) or to take complete
      authorship of the ruleset when also clearing `objects.tables`.
    '';
  };
}
