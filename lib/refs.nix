/*
  Reference-resolution helpers used by pipeline stage 2 (validate).
*/
{ lib }:

{
  # Format a list of validation error strings into a single throw-friendly
  # message. Returns null if no errors.
  formatErrors = label: errors:
    if errors == [ ] then null
    else "${label}:\n  - " + lib.concatStringsSep "\n  - " errors;
}
