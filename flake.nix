{
  description = "nixos-artifacts: backend-agnostic secret management for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Optional: backends for full integration testing
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, sops-nix, agenix }:
    let
      nixosModule = import ./modules;
    in
    {
      # ── NixOS module output ──────────────────────────────────────
      nixosModules.default = nixosModule;
      nixosModules.nixos-artifacts = nixosModule;

      # ── Overlay (empty — this project has no packages) ───────────
      overlays.default = _final: _prev: { };

    } // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        testSuite = import ./tests {
          inherit pkgs;
          nixos-artifacts = ./modules;
        };
      in
      {
        # ── Integration tests ──────────────────────────────────────
        checks = {
          inherit (testSuite)
            dummy-basic
            dummy-permissions
            dummy-ordering
            dummy-custom-path
            dummy-multiple-secrets
            dummy-idempotency
            systemd-creds-basic
            store-leak-rejected
            source-required
            ;
        };

        # ── Dev shell for contributors ─────────────────────────────
        devShells.default = pkgs.mkShell {
          name = "nixos-artifacts-dev";
          packages = with pkgs; [
            nixpkgs-fmt
            statix
            deadnix
          ];
          shellHook = ''
            echo "nixos-artifacts development shell"
            echo "  Run tests:  nix flake check"
            echo "  Format:     nixpkgs-fmt ."
            echo "  Lint:       statix check . && deadnix ."
          '';
        };
      }
    );
}
