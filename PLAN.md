# nixos-artifacts: Upstream Acceptance Plan

## Assessment (2026-05-13)

### Current State

**Repository:** `Mutasem-mk4/nixos-artifacts`
**Upstream nixpkgs PR:** #519619 (OPEN)
**RFC PR:** NixOS/rfcs#201 (OPEN, file renamed to 0201)
**Related upstream PR:** NixOS/nixpkgs#370444 (`vars` by @Lassulus/@oddlama — WIP, OPEN since Oct 2024)

### Codebase Audit

#### Module (`modules/default.nix`)
- [x] Core option interface: `security.artifacts.{enable, provider, secrets}`
- [x] Secret submodule type with `owner`, `group`, `mode`, `path`, `dummy`
- [x] Evaluation-time store-leak assertions
- [x] `nixos-artifacts-secrets.target` for systemd ordering
- [ ] Missing `lib.mdDoc` on all option descriptions
- [ ] Missing `meta.maintainers` and `meta.doc` attributes
- [ ] Missing per-secret `source` option (needed for agenix/sops file mapping)
- [ ] `path` type uses `lib.types.path` which can be a store path — should use `lib.types.str`

#### Providers

| Provider | File | Functional | Issues |
|----------|------|-----------|--------|
| `dummy` | `providers/dummy.nix` | ✅ Works | Shell injection risk in `printf` with user-controlled `dummy` string |
| `sops-nix` | `providers/sops-nix.nix` | ⚠️ Partial | Maps to `sops.secrets` but does NOT pass `sopsFile` — users cannot specify which encrypted file to use. Missing `sopsFile` option per-secret. |
| `agenix` | `providers/agenix.nix` | ⚠️ Partial | Hardcodes `file = /etc/nixos/secrets/${name}.age` which is incorrect — agenix expects a Nix path, not a runtime string. Missing `source` option. |
| `systemd-creds` | `providers/systemd-creds.nix` | ⚠️ Partial | Assumes creds at `/etc/systemd/creds/${name}.cred`. Works for the happy path but has no validation and no `credSource` option. |

#### Tests (`tests/`)

| Test | Status | Quality |
|------|--------|---------|
| `dummy-basic` | ✅ | Adequate |
| `dummy-permissions` | ✅ | Good — tests owner/group/mode |
| `dummy-ordering` | ✅ | Good — tests systemd target ordering |
| `store-leak-rejected` | ⚠️ | Uses `pkgs.nixos {}` which may not work correctly in all contexts |
| `systemd-creds-basic` | ⚠️ | Mocks credential file — doesn't test real systemd-creds flow |
| `regression-rebuild` | ⚠️ | Calls `nixos-rebuild switch` in VM — may fail without proper system closure |

**Missing tests:**
- No sops-nix integration test
- No agenix integration test
- No negative test for invalid provider selection
- No test for custom `path` option
- No idempotency test (checking no changes on second run)

#### Documentation
- `README.md` — Basic, adequate for a standalone flake
- `doc/nixos-artifacts.md` — Draft manual section, needs expansion
- `discourse-post.md` — Well-written pre-RFC discussion post

#### Flake Structure
- Uses `flake-utils.eachDefaultSystem` — acceptable for standalone, must be removed for nixpkgs
- Imports `sops-nix` and `agenix` as flake inputs — correct for standalone testing
- Tests use `pkgs.callPackage` pattern — good

---

## Action Plan

### Phase 1: Fix Critical Issues in Standalone Repo

1. **Fix `path` option type** — Change from `lib.types.path` to `lib.types.str` to prevent accidental store path coercion
2. **Add `source` option** — Per-secret `source` path for encrypted file (used by sops-nix and agenix)
3. **Fix sops-nix provider** — Wire `sopsFile` from the new `source` option
4. **Fix agenix provider** — Wire `file` from the new `source` option, use proper Nix path type
5. **Harden dummy provider** — Use `pkgs.writeText` instead of shell `printf` to avoid injection
6. **Add `lib.mdDoc`** to all option descriptions
7. **Add validation assertions** — Require `source` when provider is sops-nix or agenix

### Phase 2: Expand Test Suite

1. Add sops-nix integration test (using mock encrypted files)
2. Add agenix integration test (using mock age files)
3. Add negative test for missing `source` with sops-nix provider
4. Add custom `path` test
5. Fix `store-leak-rejected` to use proper eval-time test pattern
6. Fix `regression-rebuild` to be actually runnable

### Phase 3: Polish Documentation

1. Expand `doc/nixos-artifacts.md` with per-backend examples
2. Add `meta.doc` and `meta.maintainers` to module
3. Update README with badges, architecture diagram, and status

### Phase 4: Upstream Integration

1. Comment on PR #370444 offering collaboration
2. Update nixpkgs fork with clean module placement
3. Update PR #519619 with improved code
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
