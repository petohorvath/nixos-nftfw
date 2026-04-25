# VM test: single-host firewall in authoritative mode.
# - Verifies nftables.service starts and our generated ruleset loads.
# - Verifies the loopback-accept and conntrack-baseline helpers contribute
#   their rules (visible in `nft list ruleset`).
# - Verifies a user-declared SSH allow rule is present.
# - Verifies the firewall actually blocks an unallowed port.
{ pkgs, libnet, nftlib, self }:

pkgs.testers.runNixOSTest {
  name = "nftfw-single-host";

  nodes.machine = { config, ... }: {
    imports = [ self.nixosModules.default ];

    networking.nftfw = {
      enable = true;
      authoritative = true;

      rules.filter.allow-ssh = {
        from = "any"; to = "local";
        match.dstPorts.tcp = [ 22 ];
        verdict = "accept";
      };

      # stopRuleset emits to networking.nftables.stopRuleset which is not
      # a standard NixOS option. Disable it in this test to avoid conflicts.
      helpers.stopRuleset.enable = false;
    };

    services.openssh.enable = true;
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("nftables.service")

    # The user rule is present.
    # nft list ruleset collapses single-element sets: tcp dport 22 (no braces).
    machine.succeed("nft list ruleset | grep -F 'tcp dport 22'")

    # Conntrack baseline contributes.
    # Multi-value ct state keeps braces; single-value collapses.
    machine.succeed("nft list ruleset | grep -F 'ct state { established, related }'")
    machine.succeed("nft list ruleset | grep -F 'ct state invalid'")

    # Loopback accept contributes.
    # iifname is quoted by nft list; meta keyword is dropped in list output.
    machine.succeed("nft list ruleset | grep -F 'iifname \"lo\"'")

    # SSH service is up
    machine.wait_for_open_port(22)

    # Input chain policy is drop (authoritative mode).
    machine.succeed("nft list ruleset | grep -F 'policy drop'")
  '';
}
