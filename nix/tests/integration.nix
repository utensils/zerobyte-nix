# NixOS VM integration test for Zerobyte
{ pkgs, self }:

pkgs.testers.nixosTest {
  name = "zerobyte-integration";

  nodes.machine =
    { config, pkgs, ... }:
    {
      imports = [ self.nixosModules.default ];

      services.zerobyte = {
        enable = true;
        openFirewall = true;
      };

      # Add curl for healthcheck test
      environment.systemPackages = [ pkgs.curl ];

      # Ensure the test VM has enough resources
      virtualisation = {
        memorySize = 1024;
        diskSize = 2048;
      };
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("zerobyte.service")
    machine.wait_for_open_port(4096)

    # Test healthcheck endpoint (returns {"status":"ok"})
    result = machine.succeed("curl -s http://localhost:4096/healthcheck")
    assert '"status":"ok"' in result or '"ok"' in result, f"Healthcheck failed: {result}"

    machine.log("Zerobyte integration test passed!")
  '';
}
