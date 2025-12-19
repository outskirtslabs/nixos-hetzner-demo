{
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1"; # tracks nixpkgs unstable branch
    # TODO: switch this back to nixos/nixpkgs once https://github.com/NixOS/nixpkgs/pull/375551 is merged
    nixpkgs-mine.url = "git+https://github.com/ramblurr/nixpkgs?shallow=1&ref=consolidated";

    flakelight.url = "github:m15a/flakelight-treefmt";

    nixos-hetzner.url = "https://flakehub.com/f/outskirtslabs/nixos-hetzner/*";
    nixos-hetzner.inputs.nixpkgs.follows = "nixpkgs";

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/0.1.*";
  };

  outputs =
    { flakelight, ... }@inputs:
    flakelight ./. {
      inherit inputs;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      devShell.packages =
        pkgs: with pkgs; [
          opentofu
          inputs.nixpkgs-mine.legacyPackages.${pkgs.system}.hcloud
          inputs.nixpkgs-mine.legacyPackages.${pkgs.system}.hcloud-upload-image
          inputs.nixos-hetzner.packages.${pkgs.system}.hcloud-smoke-test
          jq
        ];

      treefmtConfig = {
        programs.nixfmt.enable = true;
        programs.terraform.enable = true;
      };

      nixosConfigurations.cryptpad-demo = {
        system = "x86_64-linux";
        modules = [
          inputs.determinate.nixosModules.default
          "${inputs.nixpkgs-mine}/nixos/modules/virtualisation/hcloud-config.nix"
          # Overlay to add hcloud packages from nixpkgs-mine (pending upstream PR #375551)
          {
            nixpkgs.overlays = [
              (final: prev: {
                hcloud = inputs.nixpkgs-mine.legacyPackages.${prev.system}.hcloud;
                hcloud-upload-image = inputs.nixpkgs-mine.legacyPackages.${prev.system}.hcloud-upload-image;
                systemd-network-generator-hcloud =
                  inputs.nixpkgs-mine.legacyPackages.${prev.system}.systemd-network-generator-hcloud;
              })
            ];
          }
          (
            { pkgs, ... }:
            {

              environment.systemPackages = [
                inputs.fh.packages.${pkgs.system}.default
              ];

              services.openssh.enable = true;
              services.openssh.settings.PermitRootLogin = "prohibit-password";

              networking.firewall.allowedTCPPorts = [
                22
                80
              ];

              services.cryptpad = {
                enable = true;
                settings = {
                  httpUnsafeOrigin = "http://localhost";
                  httpSafeOrigin = "http://localhost";
                  httpAddress = "127.0.0.1";
                  httpPort = 3000;
                };
              };

              # Use nginx as reverse proxy for port 80
              services.nginx = {
                enable = true;
                virtualHosts.default = {
                  default = true;
                  locations."/" = {
                    proxyPass = "http://127.0.0.1:3000";
                    proxyWebsockets = true;
                  };
                };
              };

              networking.hostName = "cryptpad-demo";
              system.stateVersion = "25.11";
            }
          )
        ];
      };
    };
}
