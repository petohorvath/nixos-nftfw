/*
  Priority band constants for kind-typed rules.

  Used by the dispatch generator and by helper modules
  to slot rules into the appropriate position within
  a per-zone dispatch chain.
*/
{
  preDispatch = 50;    # 1-99   — infrastructure (bogons, conntrack baseline, early drops)
  early       = 250;   # 100-499 — early management
  default     = 500;   # 500    — most user rules
  late        = 750;   # 501-899 — late management
  deny        = 950;   # 900-999 — log-and-drop, final deny
}
