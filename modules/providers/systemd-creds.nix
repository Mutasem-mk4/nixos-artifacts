{ config, lib, pkgs, ... }:

let
  cfg = config.security.artifacts;
  credsSecrets = lib.filterAttrs (_: secret: 
    let p = if secret.provider != null then secret.provider else cfg.provider;
    in secret.enable && p == "systemd-creds"
  ) cfg.secrets;
in {
  config = lib.mkIf (cfg.enable && credsSecrets != {}) {
    systemd.services = lib.mapAttrs' (name: secret:
      lib.nameValuePair "nixos-artifacts-creds-${name}" {
        description = "Provision systemd credential '${name}'";
        wantedBy = [ "nixos-artifacts-secrets.target" ];
        before = [ "nixos-artifacts-secrets.target" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          LoadCredential = "${name}:/etc/credstore/${name}";
        };

        script = ''
          install -D -m "${secret.mode}" /dev/null "${secret.path}"
          cp "$CREDENTIALS_DIRECTORY/${name}" "${secret.path}"
          chown "${secret.owner}:${secret.group}" "${secret.path}"
          chmod "${secret.mode}" "${secret.path}"
        '';
      }
    ) credsSecrets;
  };
}
