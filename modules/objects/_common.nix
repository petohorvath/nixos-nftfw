{ lib }:

{
  # Fields shared by every nftables primitive with F3 auto-emission scoping.
  commonFields = {
    tables = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      description = ''
        Emission scope. null = auto-emit to every declared table whose
        family is compatible; list = explicit restriction to named tables.
      '';
    };
    comment = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Free-form comment carried into the generated ruleset.";
    };
  };
}
