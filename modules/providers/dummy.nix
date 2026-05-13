{ config, lib, pkgs, ... }:

let
  cfg = config.security.artifacts;
  dummySecrets = lib.filterAttrs (_: secret: 
    let p = if secret.provider != null then secret.provider else cfg.provider;
    in secret.enable && p == "dummy"
  ) cfg.secrets;
in {
  config = lib.mkIf (cfg.enable && dummySecrets != {}) {
    systemd.services = lib.mapAttrs' (name: secret:
      let
        dummyContent = pkgs.writeText "dummy-${name}" secret.dummy;
      in lib.nameValuePair "nixos-artifacts-dummy-${name}" {
        description = "Provision dummy secret '${name}'";
        wantedBy = [ "nixos-artifacts-secrets.target" ];
        before = [ "nixos-artifacts-secrets.target" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        script = ''
          install -D -m "${secret.mode}" /dev/null "${secret.path}"
          cp "${dummyContent}" "${secret.path}"
          chown "${secret.owner}:${secret.group}" "${secret.path}"
          chmod "${secret.mode}" "${secret.path}"
        '';
      }
    ) dummySecrets;
  };
}
