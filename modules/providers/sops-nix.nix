{ config, lib, pkgs, options, ... }:

let
  cfg = config.security.artifacts;
  sopsSecrets = lib.filterAttrs (_: secret: 
    let p = if secret.provider != null then secret.provider else cfg.provider;
    in secret.enable && p == "sops-nix"
  ) cfg.secrets;
in {
  config = lib.mkIf (cfg.enable && sopsSecrets != {}) (lib.mkMerge [
    {
      assertions = [
        {
          assertion = options ? sops;
          message = "security.artifacts: One or more secrets use 'sops-nix' provider, but the sops-nix module is not imported.";
        }
        {
          assertion = lib.all (s: s.source != null) (lib.attrValues sopsSecrets);
          message = "security.artifacts: One or more secrets using 'sops-nix' are missing the 'source' option.";
        }
      ];

      systemd.targets.nixos-artifacts-secrets = {
        after = [ "sops-nix.service" ];
        requires = [ "sops-nix.service" ];
      };
    }
    (lib.optionalAttrs (options ? sops) {
      sops.secrets = lib.mapAttrs (_: secret: {
        inherit (secret) owner group mode path;
        sopsFile = secret.source;
      }) sopsSecrets;
    })
  ]);
}
