# TODO

- Remove `networking.nftfw._internal.ir` once the IR shape stabilizes
  and snapshot tests are the single source of truth.
- Consider exposing JSON rendering as a user-facing `format` option
  if a deployment hits a known text-renderer edge case.
- Add vmap-based dispatch variant behind an internal toggle if
  zone counts exceed O(100).
- Add a 3-VM router VM test (wan + gw + lan) covering NAT/forwarding,
  zone hierarchy, and DNAT-via-node. Deferred from Task 26 to keep
  the initial CI fast.
