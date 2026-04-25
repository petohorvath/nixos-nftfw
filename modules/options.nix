/*
  Top-level option surface for networking.nftfw.

  Declares `enable`, `authoritative` (own vs. cooperate with the
  kernel firewall), and the internal `_internal.ir` read-only attr
  for debugging. Also declares the module-private
  `networking.nftables.stopRuleset` extension used by the
  stop-ruleset helper.
*/
{ lib }:

{ config, ... }:

{
  options.networking.nftfw = {
    enable = lib.mkEnableOption "nftfw firewall module";

    authoritative = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When true, the module owns the kernel firewall: flushes the
        ruleset at load and disables networking.firewall. When false,
        coexists with other nftables contributors.
      '';
    };

    _internal.ir = lib.mkOption {
      type = lib.types.attrs;
      internal = true;
      readOnly = true;
      description = "Computed IR for debugging. TODO: remove once stable.";
    };
  };

  # NixOS-standard options (networking.nftables.enable, .flushRuleset, .ruleset,
  # .tables, networking.firewall.enable, boot.kernel.sysctl) are NOT declared here;
  # they are provided by the full NixOS module system in production. For standalone
  # eval the harness.nix stubs module supplies them — see tests/harness.nix.
  #
  # networking.nftables.stopRuleset is a module-private extension that is NOT part
  # of the upstream NixOS nftables module. We declare it here so both standalone
  # eval and NixOS context can use it; NixOS's nftables module ignores unknown
  # options unless something wires it to the systemd unit's ExecStop.
  options.networking.nftables.stopRuleset = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = ''
      Minimal-safe nftables ruleset to load when the nftables service stops.
      Wired to nftables.service ExecStop by the stop-ruleset helper.
      This option is a nftfw extension; the upstream NixOS nftables module
      does not declare or use it.
    '';
  };
}
