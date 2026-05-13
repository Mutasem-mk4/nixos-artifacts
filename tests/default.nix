{ pkgs ? import <nixpkgs> {}, nixos-artifacts ? ../modules, ... }:

{
  # ── Dummy provider tests ──────────────────────────────────────────
  dummy-basic = pkgs.callPackage ./dummy-basic.nix { inherit nixos-artifacts; };
  dummy-permissions = pkgs.callPackage ./dummy-permissions.nix { inherit nixos-artifacts; };
  dummy-ordering = pkgs.callPackage ./dummy-ordering.nix { inherit nixos-artifacts; };
  dummy-custom-path = pkgs.callPackage ./dummy-custom-path.nix { inherit nixos-artifacts; };
  dummy-multiple-secrets = pkgs.callPackage ./dummy-multiple-secrets.nix { inherit nixos-artifacts; };
  dummy-idempotency = pkgs.callPackage ./dummy-idempotency.nix { inherit nixos-artifacts; };

  # ── systemd-creds provider tests ──────────────────────────────────
  systemd-creds-basic = pkgs.callPackage ./systemd-creds-basic.nix { inherit nixos-artifacts; };

  # ── Evaluation-time assertion tests ───────────────────────────────
  store-leak-rejected = pkgs.callPackage ./store-leak-rejected.nix { inherit nixos-artifacts; };
  source-required = pkgs.callPackage ./source-required.nix { inherit nixos-artifacts; };
}
