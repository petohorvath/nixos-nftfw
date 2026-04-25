/*
  Reference-resolution helpers used by pipeline stage 2 (validate).
*/
{ lib }:

rec {
  # Returns the list of names from `names` that don't exist as attrs in
  # `universe`. Empty list = all names present.
  missingNames = names: universe:
    let
      list = if builtins.isList names then names else [ names ];
    in
      lib.filter (n: !(lib.hasAttr n universe)) list;

  # Format a list of validation error strings into a single throw-friendly
  # message. Returns null if no errors.
  formatErrors = label: errors:
    if errors == [ ] then null
    else "${label}:\n  - " + lib.concatStringsSep "\n  - " errors;
}
