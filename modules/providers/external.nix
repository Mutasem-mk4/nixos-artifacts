{ config, lib, pkgs, ... }:

let
  cfg = config.security.artifacts;
  externalSecrets = lib.filterAttrs (_: secret: 
    let p = if secret.provider != null then secret.provider else cfg.provider;
    in secret.enable && p == "external"
  ) cfg.secrets;
in {
  config = lib.mkIf (cfg.enable && externalSecrets != {}) {
    # The external provider does nothing. It assumes the secret is already
    # provisioned by an external mechanism (e.g. manual copy, cloud-init,
    # or a custom activation script).
    #
    # It allows referencing these secrets via the unified
    # security.artifacts.secrets.<name>.path interface.
    
    # We still want to ensure dependent services wait for the synchronization target.
    systemd.targets.nixos-artifacts-secrets = {
      # No dependencies needed as we assume external provisioning is done.
    };
  };
}
