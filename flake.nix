{
  # TODO: switch this back to nixos/nixpkgs once https://github.com/NixOS/nixpkgs/pull/375551 is merged
  inputs.nixpkgs.url = "git+https://github.com/ramblurr/nixpkgs?shallow=1&ref=consolidated";
  inputs.nixos-hetzner.url = "github:outskirtslabs/nixos-hetzner";
  inputs.nixos-hetzner.inputs.nixpkgs.follows = "nixpkgs";
  inputs.determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/=0.1.95";
  inputs.fh.url = "https://flakehub.com/f/DeterminateSystems/fh/=0.1.16";

  outputs =
    inputs:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = f: inputs.nixpkgs.lib.genAttrs supportedSystems (system: (forSystem system f));

      forSystem =
        system: f:
        f rec {
          inherit system;
          pkgs = import inputs.nixpkgs {
            inherit system;
          };
          lib = pkgs.lib;
        };
    in
    {
      nixosConfigurations.ethercalc-demo = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          "${inputs.nixpkgs}/nixos/modules/virtualisation/hcloud-config.nix"
          inputs.determinate.nixosModules.default
          (
            { pkgs, ... }:
            {
              environment.systemPackages = [
                inputs.fh.packages."${pkgs.stdenv.system}".default
              ];
            }
          )
          (
            { pkgs, ... }:
            {
              # Enable SSH for deployment
              services.openssh.enable = true;
              services.openssh.settings.PermitRootLogin = "prohibit-password";

              networking.firewall.allowedTCPPorts = [ 22 80 ];
              systemd.services.ethercalc.serviceConfig.AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
              services.ethercalc = {
                enable = true;
                port = 80;
              };

              services.writefreely = {
                enable = false;
                host = "0.0.0.0";
                settings.server.bind = "0.0.0.0";
              };
            }
          )
        ];
      };

      devShells = forAllSystems (
        { system, pkgs, ... }:
        {
          default = pkgs.mkShell {
            name = "demo-shell";
            buildInputs = with pkgs; [
              opentofu
              hcloud
              hcloud-upload-image
              inputs.nixos-hetzner.packages."${pkgs.stdenv.system}".hcloud-smoke-test
              jq
            ];
          };
        }
      );
    };
}
