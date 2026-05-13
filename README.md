# nixos-artifacts

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Status](https://img.shields.io/badge/status-pre--rfc-orange.svg)

`nixos-artifacts` is a backend-agnostic secret management interface for NixOS. It decouples NixOS service modules from specific secret providers (like `sops-nix`, `agenix`, or `systemd-creds`).

## The Problem
NixOS service modules often hardcode their dependency on a specific secret management tool. If a service module requires `sops-nix`, a user who prefers `agenix` is forced to either adopt multiple backends or rewrite the module. 

## The Solution
Service modules declare their secret requirements using a unified interface (`security.artifacts`). The system administrator then selects a single backend provider (`sops-nix`, `agenix`, `systemd-creds`, or `dummy`) to fulfill all requirements across the system. 

## Quick Start
```nix
{ config, pkgs, ... }:

{
  # 1. Enable artifacts and choose a provider for your whole system
  security.artifacts.enable = true;
  security.artifacts.provider = "sops-nix"; # or "agenix", "systemd-creds", "dummy"

  # 2. Declare a secret for your service
  security.artifacts.secrets."db-password" = {
    owner = "postgres";
    group = "postgres";
    mode = "0400";
    # dummy = "dev-password"; # Fallback for CI/CD environments
  };

  # 3. Consume the secret in a service (automatically available at /run/secrets/db-password)
  services.postgresql.enable = true;
  systemd.services.postgresql.wants = [ "nixos-artifacts-secrets.target" ];
  systemd.services.postgresql.after = [ "nixos-artifacts-secrets.target" ];
}
```

## Backend Comparison
*   `sops-nix`: Full ecosystem support, multi-key encryption. Requires external flake.
*   `agenix`: Minimalist age-based encryption. Requires external flake.
*   `systemd-creds`: Native systemd feature, TPM2 support. Zero third-party dependencies.
*   `dummy`: Writes plaintext strings directly. CI/CD integration only.

## Contributing
Follow the nixpkgs contribution guidelines. Integration tests are managed through NixOS VM tests via `nix flake check`.

## License
MIT
