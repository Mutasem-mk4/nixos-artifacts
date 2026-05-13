{ config, lib, pkgs, ... }:

let
  cfg = config.security.artifacts;

  secretType = lib.types.submodule ({ name, ... }: {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = lib.mdDoc "Whether to enable provisioning for this specific secret.";
      };
      provider = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [ "sops-nix" "agenix" "systemd-creds" "dummy" "external" ]);
        default = null;
        description = lib.mdDoc ''
          The secret management backend for this specific secret.
          Defaults to the global `security.artifacts.provider`.
        '';
      };
      owner = lib.mkOption {
        type = lib.types.str;
        default = "root";
        description = lib.mdDoc "User that owns the deployed secret file.";
      };
      group = lib.mkOption {
        type = lib.types.str;
        default = "root";
        description = lib.mdDoc "Group that owns the deployed secret file.";
      };
      mode = lib.mkOption {
        type = lib.types.str;
        default = "0400";
        description = lib.mdDoc "Octal permission mode for the deployed secret file.";
      };
      path = lib.mkOption {
        type = lib.types.str;
        default = "/run/secrets/${name}";
        description = lib.mdDoc ''
          Absolute path where the secret will be deployed at runtime.
          Defaults to `/run/secrets/${name}`.

          ::: {.warning}
          This path must NOT be inside `/nix/store`.
          :::
        '';
      };
      source = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = lib.mdDoc ''
          Path to the encrypted source file for this secret (e.g. .age or .yaml).
          Required for `sops-nix` and `agenix` providers.
        '';
      };
      dummy = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = lib.mdDoc "Placeholder content used when the `dummy` provider is active.";
      };
    };
  });

in {
  imports = [
    ./providers/sops-nix.nix
    ./providers/agenix.nix
    ./providers/systemd-creds.nix
    ./providers/dummy.nix
    ./providers/external.nix
  ];

  options.security.artifacts = {
    enable = lib.mkEnableOption (lib.mdDoc "backend-agnostic secret management");

    provider = lib.mkOption {
      type = lib.types.enum [ "sops-nix" "agenix" "systemd-creds" "dummy" "external" ];
      default = "dummy";
      description = lib.mdDoc "Global default provider for secrets.";
    };

    secrets = lib.mkOption {
      type = lib.attrsOf secretType;
      default = {};
      description = lib.mdDoc "Declarative secret requirements.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      # 1. Prevent store leakage
      (lib.mapAttrsToList (name: secret: {
        assertion = !(lib.hasPrefix builtins.storeDir (builtins.toString secret.path));
        message = "security.artifacts: secret '${name}' resolves to '${secret.path}', which is inside /nix/store.";
      }) cfg.secrets)

      ++

      # 2. Source requirement check
      (lib.mapAttrsToList (name: secret:
        let
          activeProvider = if secret.provider != null then secret.provider else cfg.provider;
        in {
          assertion = (activeProvider == "sops-nix" || activeProvider == "agenix") -> secret.source != null;
          message = "security.artifacts: secret '${name}' requires 'source' for provider '${activeProvider}'.";
        }
      ) cfg.secrets);

    systemd.targets.nixos-artifacts-secrets = {
      description = "All nixos-artifacts secrets have been provisioned";
      requires = [ "local-fs.target" ];
      after = [ "local-fs.target" ];
    };
  };
}
