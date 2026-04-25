# Helper: minimal-safe nftables ruleset loaded on service stop.
#
# Wired to `networking.nftables.stopRuleset`. Defaults to enabled in
# authoritative mode. The default `keepAlivePorts` includes the OpenSSH
# port if `services.openssh.enable` is true.
{ lib }:

{ config, ... }:

let
  cfg = config.networking.nftfw;
  hcfg = cfg.helpers.stopRuleset;

  sshPorts =
    if (lib.attrByPath [ "services" "openssh" "enable" ] false config)
    then lib.attrByPath [ "services" "openssh" "ports" ] [ 22 ] config
    else [ ];

  portList = lib.concatMapStringsSep ", " toString hcfg.keepAlivePorts;

  rulesetText = ''
    flush ruleset

    table inet nftfw-stop {
      chain input {
        type filter hook input priority 0; policy drop;
        iifname "lo" accept
        ct state established,related accept
    ${lib.optionalString (hcfg.keepAlivePorts != [ ]) "    tcp dport { ${portList} } accept"}
      }
      chain forward {
        type filter hook forward priority 0; policy drop;
      }
      chain output {
        type filter hook output priority 0; policy accept;
      }
    }
  '';
in {
  options.networking.nftfw.helpers.stopRuleset = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.authoritative;
      description = ''
        Install a minimal-safe ruleset under `networking.nftables.stopRuleset`.
        Loaded by nftables.service on stop so remote sessions survive rule reloads.
      '';
    };
    keepAlivePorts = lib.mkOption {
      type = lib.types.listOf lib.types.int;
      default = sshPorts;
      defaultText = lib.literalExpression ''
        if config.services.openssh.enable
        then config.services.openssh.ports or [ 22 ]
        else [ ]
      '';
      description = ''
        TCP destination ports to accept while the stop ruleset is in
        effect. Defaults to the configured OpenSSH ports (or [22] if
        OpenSSH is enabled but no port list is set), or [] if OpenSSH
        is disabled.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && hcfg.enable) {
    networking.nftables.stopRuleset = lib.mkDefault rulesetText;
  };
}
