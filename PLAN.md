# nixos-artifacts: Upstream Acceptance Plan

### Assessment (2026-05-13)

### Current State

**Repository:** `Mutasem-mk4/nixos-artifacts`
**Upstream nixpkgs PR:** #519619 (OPEN)
**RFC PR:** NixOS/rfcs#201 (OPEN, renamed to 0201)
**Related upstream PR:** NixOS/nixpkgs#370444 (`vars` by @Lassulus/@oddlama — WIP, OPEN since Oct 2024)

### Codebase Audit

#### Module (`modules/default.nix`)
- [x] Core option interface: `security.artifacts.{enable, provider, secrets}`
- [x] Secret submodule type with `owner`, `group`, `mode`, `path`, `dummy`
- [x] Evaluation-time store-leak assertions
- [x] `nixos-artifacts-secrets.target` for systemd ordering
- [x] Support for per-secret `provider` overrides
- [x] Fixed `path` type (now `lib.types.str`)
- [x] Added `source` option for encrypted file mapping
- [x] Added `meta.maintainers` and `meta.doc`
- [x] Cleaned up `lib.mdDoc` on all options

#### Providers

| Provider | File | Functional | Status |
|----------|------|-----------|--------|
| `dummy` | `providers/dummy.nix` | ✅ Works | Refactored for multi-provider |
| `sops-nix` | `providers/sops-nix.nix` | ✅ Functional | Fixed `source` mapping |
| `agenix` | `providers/agenix.nix` | ✅ Functional | Fixed `source` mapping |
| `systemd-creds` | `providers/systemd-creds.nix` | ✅ Functional | Fixed logic |
| `external` | `providers/external.nix` | ✅ New | Added for manual provisioning |

---

## Action Plan

### Phase 1: Fix Critical Issues in Standalone Repo (COMPLETED)

1. [x] **Fix `path` option type**
2. [x] **Add `source` option**
3. [x] **Fix sops-nix provider**
4. [x] **Fix agenix provider**
5. [x] **Harden dummy provider** (Used `pkgs.writeText`)
6. [x] **Add `lib.mdDoc`**
7. [x] **Support Mixed Providers**

### Phase 2: Expand Test Suite (NEXT)

1. Add sops-nix integration test
2. Add agenix integration test
3. Add negative test for missing `source` with sops-nix provider
4. Add custom `path` test
5. Fix `store-leak-rejected`
6. Fix `regression-rebuild`

### Phase 3: Polish Documentation (IN PROGRESS)

1. [x] Rename RFC file to 0201
2. [x] Update RFC with multi-provider/mixed examples
3. [ ] Expand `doc/nixos-artifacts.md` with per-backend examples

### Phase 4: Upstream Integration (IN PROGRESS)

1. [x] Comment on PR #370444 offering collaboration
2. [x] Respond to RFC feedback on #201
3. [ ] Update PR #519619 with improved code
te PR #519619 with improved code
4. Respond to any RFC feedback on #201

---

## Relationship to `vars` (PR #370444)

The `vars` approach by @Lassulus is broader: it handles both secrets and public "facts" with
generators. `nixos-artifacts` is narrower and more opinionated: it targets specifically the
secret provisioning lifecycle. The two are complementary:

- `vars` could use `nixos-artifacts` as its secret-file backend
- `nixos-artifacts` could adopt `vars`-style generators in the future
- Both share the goal of decoupling modules from specific secret tools

Our approach: Position `nixos-artifacts` as a pragmatic, shippable-now solution that
doesn't conflict with `vars` long-term direction.
