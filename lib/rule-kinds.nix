/*
  Single source of truth for the kind-typed rule kinds the pipeline
  knows about.

  Used by ir-rules and ir-tables to iterate the rule-kind submodule
  paths under `networking.nftfw.rules.<kind>`.
*/
{
  kinds = [ "filter" "icmp" "mangle" "dnat" "snat" "redirect" ];
}
