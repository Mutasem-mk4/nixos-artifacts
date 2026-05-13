# nixos-artifacts

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)
[![Status](https://img.shields.io/badge/status-pre--RFC-orange.svg)](https://github.com/NixOS/rfcs/pull/201)
[![nixpkgs PR](https://img.shields.io/badge/nixpkgs-PR%20%23519619-green.svg)](https://github.com/NixOS/nixpkgs/pull/519619)

**Backend-agnostic secret management for NixOS.**

`nixos-artifacts` provides a unified interface (`security.artifacts`) that
decouples NixOS service modules from specific secret providers. Module
authors declare *what* secrets they need; operators choose *how* those
secrets are provisioned.

## The Problem

NixOS service modules that handle secrets face fragmentation:
- **sops-nix** users configure `sops.secrets.*`
- **agenix** users configure `age.secrets.*`
- **systemd-creds** users roll custom activation scripts
- Modules published in nixpkgs cannot reference any of these without a
  hard dependency on a third-party flake

This forces module authors to either pick one backend or provide untyped
`passwordFile` string options with no validation.

## The Solution

```
┌──────────────┐    declares    ┌──────────────────────────┐
│ Service      │ ──────────▶   │ security.artifacts       │
│ Module       │   "I need     │   .secrets.<name>        │
│              │    a secret"  │   { owner, mode, … }     │
└──────────────┘               └───────────┬──────────────┘
                                           │
                              ┌────────────▼──────────────┐
                              │ Active Provider            │
                              │ sops-nix │ agenix │        │
                              │ systemd-creds │ dummy      │
                              └───────────────────────────┘
```

## Quick Start

```nix
{
  # In your flake.nix inputs:
  # nixos-artifacts.url = "github:Mutasem-mk4/nixos-artifacts";

  security.artifacts.enable = true;
  security.artifacts.provider = "sops-nix"; # or "agenix", "systemd-creds", "dummy"

  security.artifacts.secrets."db-password" = {
    source = ./secrets/db-password.yaml; # encrypted source (sops-nix/agenix only)
    owner = "postgres";
    group = "postgres";
    mode = "0400";
  };

  # Services automatically consume secrets from /run/secrets/<name>
  systemd.services.postgresql.wants = [ "nixos-artifacts-secrets.target" ];
  systemd.services.postgresql.after = [ "nixos-artifacts-secrets.target" ];
}
```

## Supported Providers

| Provider | Description | Dependencies |
|----------|-------------|-------------|
| `sops-nix` | Full ecosystem, multi-key encryption | [sops-nix](https://github.com/Mic92/sops-nix) flake |
| `agenix` | Minimalist age-based encryption | [agenix](https://github.com/ryantm/agenix) flake |
| `systemd-creds` | Native systemd, TPM2 support | None (built-in) |
| `dummy` | Plaintext placeholders | None (CI/CD only) |

## Security Guarantees

- **No Nix store leakage**: Evaluation-time assertions reject any secret
  path inside `/nix/store`
- **Least privilege defaults**: `root:root`, mode `0400`
- **Ordering guarantees**: `nixos-artifacts-secrets.target` ensures all
  secrets are provisioned before dependent services start

## Documentation

- [Full NixOS Manual Section](./doc/nixos-artifacts.md) — Architecture,
  migration guide, module author guide
- [Pre-RFC Discussion](./discourse-post.md) — Design rationale and
  community feedback request
- [RFC #201](https://github.com/NixOS/rfcs/pull/201) — Formal RFC
- [nixpkgs PR #519619](https://github.com/NixOS/nixpkgs/pull/519619) —
  Upstream integration

## Testing

```bash
# Run the full test suite (9 NixOS VM integration tests)
nix flake check

# Enter development shell
nix develop
```

## Current Status

- **Module**: Complete — 4 providers, typed options, security assertions
- **Tests**: 9 NixOS VM integration tests
- **RFC**: [#201](https://github.com/NixOS/rfcs/pull/201) (open)
- **nixpkgs PR**: [#519619](https://github.com/NixOS/nixpkgs/pull/519619) (open)
- **Relationship to `vars`**: Complementary to
  [PR #370444](https://github.com/NixOS/nixpkgs/pull/370444). See
  [PLAN.md](./PLAN.md) for details.

## Contributing

Follow the [nixpkgs contribution guidelines](https://github.com/NixOS/nixpkgs/blob/master/CONTRIBUTING.md).
Format with `nixpkgs-fmt`, lint with `statix check .` and `deadnix .`.

## License

[MIT](./LICENSE) — Mutasem Kharma © 2026
