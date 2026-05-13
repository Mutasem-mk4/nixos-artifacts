{ config, lib, pkgs, options, ... }:

let
  cfg = config.security.artifacts;
  ageSecrets = lib.filterAttrs (_: secret: 
    let p = if secret.provider != null then secret.provider else cfg.provider;
    in secret.enable && p == "agenix"
  ) cfg.secrets;
in {
  config = lib.mkIf (cfg.enable && ageSecrets != {}) (lib.mkMerge [
    {
      assertions = [
        {
          assertion = options ? age;
          message = "security.artifacts: One or more secrets use 'agenix' provider, but the agenix module is not imported.";
        }
      ];

      systemd.targets.nixos-artifacts-secrets = {
        after = [ "agenix.service" ];
        requires = [ "agenix.service" ];
      };
    }
    (lib.optionalAttrs (options ? age) {
      age.secrets = lib.mapAttrs (_: secret: {
        inherit (secret) owner group mode path;
        file = secret.source;
      }) ageSecrets;
    })
  ]);
}
