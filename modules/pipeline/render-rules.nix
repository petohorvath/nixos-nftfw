# Stage 7 dispatcher. Maps each rule kind to its renderer; returns the
# rendered statement list for any resolvedRule.
{ lib, nftlib }:

let
  renderers = {
    filter   = import ./renderers/filter.nix   { inherit lib nftlib; };
    icmp     = import ./renderers/icmp.nix     { inherit lib nftlib; };
    mangle   = import ./renderers/mangle.nix   { inherit lib nftlib; };
    dnat     = import ./renderers/dnat.nix     { inherit lib nftlib; };
    snat     = import ./renderers/snat.nix     { inherit lib nftlib; };
    redirect = import ./renderers/redirect.nix { inherit lib nftlib; };
  };
in {
  render = { resolvedRule, zonePredicates ? { }, refs ? { } }:
    renderers.${resolvedRule.kind} {
      inherit resolvedRule zonePredicates refs;
    };
}
