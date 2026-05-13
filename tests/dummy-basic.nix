{ pkgs, ... }:

pkgs.testers.nixosTest {
  name = "dummy-basic";
  nodes.machine = { config, lib, ... }: {
    imports = [ ../modules/default.nix ];
    
    security.artifacts.enable = true;
    security.artifacts.provider = "dummy";
    security.artifacts.secrets."test-secret" = {
      dummy = "hello-world";
    };
  };

  testScript = ''
    machine.wait_for_unit("nixos-artifacts-secrets.target")
    machine.succeed("grep 'hello-world' /run/secrets/test-secret")
  '';
}
