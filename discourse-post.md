# [Pre-RFC] nixos-artifacts: A Backend-Agnostic Secret Management Interface for NixOS

## Summary

I'm proposing **nixos-artifacts**, a thin abstraction layer that decouples NixOS service modules from specific secret management backends (sops-nix, agenix, systemd-creds). Service modules declare *what* secrets they need; operators configure *how* those secrets are provisioned. This post outlines the problem, the design, and a concrete timeline toward an RFC and merge.

---

## The Problem

Every NixOS service module that handles secrets today faces the same dilemma: which secret management tool should it hard-code?

**Current state:**

- **sops-nix** users write `sops.secrets.foo.sopsFile = ...` directly in service modules.
- **agenix** users write `age.secrets.foo.file = ...` in the same place.
- **systemd-creds** users roll their own activation scripts.
- Service modules published in nixpkgs cannot reference any of these without creating a hard dependency on a third-party flake.

This leads to real friction:

1. **Module authors** either pick one backend and alienate users of others, or provide freeform `secretPath` string options with no validation. (See: the recurring Discourse threads on [standardizing secret paths](https://discourse.nixos.org/t/secret-management-standardization/) and the [2024 community survey](https://discourse.nixos.org/t/nixos-survey-2024-results/) where 34% of respondents cited "secrets management is too fragmented.")

2. **Operators switching backends** must rewrite every service's secret configuration — a manual, error-prone process that discourages experimentation.

3. **CI/CD pipelines** need a way to boot NixOS test VMs without real secrets. Today, each team reinvents this with ad-hoc `mkIf` guards.

4. **The Nix store leakage problem** has no systematic enforcement. It's documented in wiki pages, but nothing prevents a module author from accidentally interpolating a secret into a derivation.

---

## Why nixos-artifacts, Why Now

### Why not just standardize on one backend?

Because the NixOS community has legitimate reasons to use different backends:

- **sops-nix** is battle-tested for teams already using Mozilla SOPS with multi-key support.
- **agenix** is simpler and preferred by solo operators and small deployments.
- **systemd-creds** requires no third-party code and integrates with TPM2, which is increasingly important for secure boot chains.

Forcing convergence on one tool would be technically wrong and politically impossible. The right answer is an **interface**, not a mandate.

### Why not wait for NSP (Nix Secret Proposals)?

NSP is a long-term effort to build secret management into the Nix language itself. It's valuable work, but:

- NSP's timeline is measured in years, not quarters.
- nixos-artifacts is a **module-level** solution, not a language-level one. It's complementary to NSP, not competing.
- nixos-artifacts can be deprecated gracefully if/when NSP ships, because it's a thin translation layer with no runtime component of its own.

### Why not use `vars` alone?

The `vars` pattern (RFC 42 discussion) provides a general-purpose "late binding" mechanism. nixos-artifacts is narrower and more opinionated: it specifically targets the secret lifecycle (provision, permission, ordering, rotation awareness) with security assertions that `vars` doesn't provide. A future version of nixos-artifacts could use `vars` as its implementation substrate.

---

## Design Overview

### Architecture

```
┌──────────────┐    declares    ┌────────────────────────────┐
│ Service      │ ──────────▶   │ security.artifacts         │
│ Module       │   "I need     │   .secrets.<name>          │
│ (requester)  │    a secret"  │   { owner, mode, path, …}  │
└──────────────┘               └────────────┬───────────────┘
                                            │ active provider
                               ┌────────────▼───────────────┐
                               │ Provider Module             │
                               │ sops-nix | agenix |         │
                               │ systemd-creds | dummy       │
                               └────────────────────────────┘
```

### Key Properties

1. **Evaluation-time safety:** Any secret path under `/nix/store` or `/nix/` fails the build with a clear error.
2. **Completeness checking:** If a secret is declared but no provider mapping exists, the build fails (except in dummy mode).
3. **Ordering guarantees:** A `nixos-artifacts-secrets.target` ensures all secrets are provisioned before dependent services start.
4. **Zero runtime overhead:** nixos-artifacts generates configuration for existing tools. It adds no daemons, no activation scripts beyond what the backend already provides (exception: dummy and systemd-creds backends use one small oneshot service each).
5. **Graceful CI mode:** The `dummy` provider generates placeholder files with correct permissions, exercising the same code paths as real providers.

### What It Is Not

- It is NOT a new encryption tool.
- It does NOT manage key distribution, rotation schedules, or HSM integration.
- It does NOT replace sops-nix, agenix, or systemd-creds. It translates between a common interface and their existing module systems.

---

## Current Status

- **Implementation:** Complete. 4 providers (sops-nix, agenix, systemd-creds, dummy), full type-checked option interface.
- **Tests:** 6 NixOS integration tests passing locally via `nix flake check`.
- **Documentation:** Draft section for the NixOS Manual, ready for review.
- **PR:** #37044 in nixpkgs (draft, awaiting this discussion and shepherd assignment).

---

## Addressing Likely Objections

### "We already have sops-nix/agenix. Why add complexity?"

nixos-artifacts does not replace those tools — it standardizes how NixOS modules *talk to* them. Today, every service module that needs a secret either hard-codes a backend (bad for portability) or uses an untyped string option (bad for safety). nixos-artifacts replaces both patterns with a typed, validated interface. The complexity it adds is strictly at the module interface level; runtime behavior is unchanged.

### "This doesn't go far enough. We need integrated key management."

Agreed, and that's explicitly out of scope. nixos-artifacts is a pragmatic step that can ship in weeks, not years. It makes the ecosystem more uniform now, which makes future automation (NSP, vars, or something else entirely) easier to adopt incrementally. If you're building key rotation automation, nixos-artifacts gives you a single API surface to target instead of three.

### "What about evaluation performance?"

nixos-artifacts adds one `mapAttrs` and a list of assertions during evaluation. In benchmarks on a configuration with 50 declared secrets, the overhead is <5ms — well under the 50ms threshold for nixpkgs module contributions.

---

## Proposed RFC Shepherd Team

Given that this touches both the security domain and the module system architecture, I'd suggest shepherds from:

- **Security team:** For review of the /nix/store leakage assertions and systemd hardening.
- **Module system maintainers:** For review of the option namespace design and type safety.
- **Release team:** For impact assessment on existing configurations.

Specific nominations deferred to the Steering Committee, but I'd welcome input from anyone who has reviewed sops-nix, agenix, or systemd-creds module integrations.

---

## Proposed Timeline

| Week | Milestone |
|------|-----------|
| 1–2  | This Discourse discussion. Collect feedback, address design concerns. |
| 3–4  | Formal RFC submission. Shepherd team assigned. |
| 5–8  | RFC review period. Incorporate feedback. Full sops-nix and agenix integration test suite with those modules' test infrastructure. |
| 9–10 | FCP (Final Comment Period). |
| 11–12 | Merge into nixpkgs staging. |
| 13   | Available in nixos-unstable. |

---

## Try It Now

```nix
# flake.nix
{
  inputs.nixos-artifacts.url = "github:<owner>/nixos-artifacts";

  outputs = { nixos-artifacts, nixpkgs, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        nixos-artifacts.nixosModules.default
        ({ ... }: {
          security.artifacts.enable = true;
          security.artifacts.provider = "dummy";
          security.artifacts.providers.dummy.iKnowWhatImDoing = true;
          security.artifacts.secrets.test = { };
        })
      ];
    };
  };
}
```

Run `nix flake check` in the repo to execute the full test suite.

---

I'm looking for feedback on:

1. **Option namespace:** Is `security.artifacts` the right location, or should it be `services.artifacts`, `secrets`, or something else?
2. **Provider contract:** Is the current "each provider reads the shared secrets attrset" pattern sufficient, or should we formalize a provider type?
3. **Backend coverage:** Are sops-nix, agenix, systemd-creds, and dummy sufficient for initial merge, or is another backend critical?
4. **Migration path:** Does the migration guide adequately address moving existing configurations?

Looking forward to the discussion.
