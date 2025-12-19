# Continuous, rapid, NixOS deployments to Hetzner Cloud

> [!NOTE]
> This repo was based on [Determinate Systems][detsys]'s [repo for AWS
> AMIs][detsys-demo]. This is a proof-of-concept repo maintained by me and not
> DetSys. I use something like this in prod, so it works, but don't expect this
> repo to be updated regularly.

This project shows you how to continuously deploy a [NixOS] configuration to a
[Hetzner Cloud][hetzner] server using [OpenTofu] and [FlakeHub] in seconds.

## Differences from the AWS demo

This repo is a port of the [Determinate Systems AWS demo][detsys-demo] to
Hetzner Cloud. Key differences:

| Aspect            | AWS Demo                                | Hetzner Demo                                         |
| ----------------- | --------------------------------------- | ---------------------------------------------------- |
| Demo app          | EtherCalc (removed from nixpkgs)        | CryptPad                                             |
| Base image        | Pre-built AMIs from Determinate Systems | Custom image built from [nixos-hetzner] and uploaded |
| FlakeHub auth     | IAM role (`determinate-nixd login aws`) | API token (`determinate-nixd login token`)           |
| Deployment method | AWS Systems Manager (SSM)               | SSH with deploy key                                  |
| Networking        | VPC, subnets, security groups           | Simple firewall rules                                |
| GitHub auth       | OIDC federation with AWS                | SSH deploy key as secret                             |

The core FlakeHub workflow remains the same: build closures in CI, publish to
FlakeHub Cache, and apply pre-built configurations in seconds.

- The initial deployment completes in less than XX seconds
- Subsequent deployments take less than XX seconds

The deployment process involves fetching a pre-built NixOS [closure][closures]
from [FlakeHub] and applying it to the Hetzner Cloud server, streamlining the
deployment process and ensuring consistency across deployments.

## Sign-up for the FlakeHub beta

To experience this streamlined NixOS deployment pipeline for yourself, [sign up
for the FlakeHub beta][detsys] at https://determinate.systems. FlakeHub provides
the enterprise-grade Nix infrastructure needed to fully use these advanced
deployment techniques.

## Prerequisites

- Paid [Hetzner Cloud account][hetzner] with an API token
- Paid [FlakeHub account][flakehub] with an API token
- [Detsys Nix] with flakes enabled
- [OpenTofu] (available in the dev shell)

## Getting Started

This demo deploys [CryptPad], a collaborative document editing platform, to a
Hetzner Cloud server.

You can trigger deployments in two ways:

- [Manual deployment](#manual-deployment) - Run OpenTofu commands from your
  local machine
- [Automated deployment](#automated-deployment-with-github-actions) - Push to
  GitHub and let CI/CD handle it

> [!TIP]
> For a full rundown of how everything in the demo works, see
> [How it works](#how-it-works) below.

### Manual deployment

#### 1. Build and upload the base image

First, build and upload a NixOS base image to Hetzner Cloud. This only needs to
be done once (or when you want to update the base image).

```shell
# Enter the dev shell
nix develop

# Set your Hetzner Cloud token
export HCLOUD_TOKEN="your-token-here"

# Build and upload the image
./scripts/upload-image.sh

# Note the image ID from the output (e.g., 123456789)
```

#### 2. Generate a deploy key

Generate an SSH key for GitHub Actions deployments:

```shell
ssh-keygen -t ed25519 -C "github-actions-deploy" -f deploy_key -N ""
```

#### 3. Configure OpenTofu

```shell
cd setup

# Copy the example config
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values:
# - hcloud_token: Your Hetzner Cloud API token
# - hcloud_image_id: The image ID from step 1
# - flakehub_token: Your FlakeHub API token
# - deploy_ssh_public_key: Contents of deploy_key.pub
# - deploy_ssh_private_key: Contents of deploy_key (private key, for first-boot provisioning)
# - (optional) ssh_public_key: Your personal SSH key for manual access
```

#### 4. Create the infrastructure

```shell
# Initialize OpenTofu
tofu init

# Validate the configuration
tofu validate

# Create the resources
tofu apply -auto-approve

# Get the website URL
export CRYPTPAD_URL=$(tofu output --json | jq -r .website.value)

# Open the website (wait ~60 seconds for first deployment)
open "${CRYPTPAD_URL}"

# When you're done, destroy the resources
tofu destroy -auto-approve
```

### Automated deployment with GitHub Actions

To enable automatic deployments via [GitHub Actions][actions], configure the
following repository secrets:

- `DEPLOY_SSH_PRIVATE_KEY`: The contents of the `deploy_key` file (private key)
- `HETZNER_SERVER_IP`: The server IP from `tofu output server_ip`

Using the `gh` CLI after completing [manual deployment](#manual-deployment):

```shell
# Create a production environment (optional)
gh api repos/{owner}/{repo}/environments/production --method PUT

# Set secrets
cat deploy_key | gh secret set DEPLOY_SSH_PRIVATE_KEY
tofu output -raw server_ip | gh secret set HETZNER_SERVER_IP
```

The workflow will automatically build, publish to FlakeHub, and deploy on pushes
to main.

## How it works

### Nix flake

The [`flake.nix`](./flake.nix) defines the NixOS configuration for the demo
system:

- Inputs:
  - `nixpkgs`: Custom nixpkgs fork with Hetzner Cloud tools
  - `nixos-hetzner`: Hetzner Cloud image building tools
  - `determinate`: Determinate Nix distribution from FlakeHub
  - `fh`: FlakeHub CLI from FlakeHub
- Outputs:
  - `nixosConfigurations.cryptpad-demo`: The CryptPad server configuration
  - `devShells.default`: Development environment with required tools

### OpenTofu configuration

The [`setup/`](./setup/) directory contains OpenTofu configuration for Hetzner
Cloud:

- `providers.tf`: Hetzner Cloud provider configuration
- `variables.tf`: Input variables (API tokens, image ID, SSH keys, etc.)
- `main.tf`: Server, firewall, and SSH key resources
- `outputs.tf`: Server IP and website URL

After server creation, Terraform provisions the server via SSH:

1. Authenticates with FlakeHub using `determinate-nixd login token`
2. Applies the NixOS configuration using `fh apply nixos`

### GitHub Actions workflow

The [`.github/workflows/ci.yml`](./.github/workflows/ci.yml) workflow:

1. Build job: Builds the NixOS closure and publishes to FlakeHub
2. Deploy job: SSHs to the server and runs `fh apply nixos` with the new closure

### Continuous deployment

Continuous deployments work by:

1. Pushing changes to the `flake.nix`
2. GitHub Actions builds the new closure
3. The closure is published to FlakeHub Cache
4. The deploy job SSHs to the server and applies the new configuration

To demonstrate, make a change to the CryptPad configuration in `flake.nix` and
push the changes.

### Triggering rollbacks

Use the `workflow_dispatch` event to manually trigger a deployment of a previous
version.

## Why FlakeHub?

Applying fully evaluated NixOS closures via [FlakeHub] differs from typical
deployments using Nix in several key ways:

### Deployment speed

- FlakeHub deployment: The NixOS configuration is evaluated and built ahead of
  time. As the closure is pre-built and cached, the deployment process is
  faster. The server only needs to download and apply the pre-built closure.
- Typical Nix deployment: The evaluation and build process happens during
  deployment, which can be time-consuming.

### Resource utilization

- FlakeHub deployment: Offloads the computationally intensive tasks of
  evaluation and building to a controlled environment (e.g., a CI/CD pipeline),
  freeing up resources on the target server.
- Typical Nix deployment: The target server must handle the evaluation and build
  process, which can be resource-intensive.

### Scalability

- FlakeHub deployment: The pre-built and cached nature allows for rapid instance
  provisioning, making it ideal for auto-scaling scenarios.
- Typical Nix deployment: The time required for evaluation and building on each
  new instance can introduce significant delays.

In summary, applying a fully evaluated NixOS closure from [FlakeHub] ensures
that the exact same configuration is deployed every time, as the closure is a
fixed, immutable artifact.

## GitHub Secrets Required

| Secret                   | Description                            |
| ------------------------ | -------------------------------------- |
| `DEPLOY_SSH_PRIVATE_KEY` | Ed25519 private key for SSH deployment |
| `HETZNER_SERVER_IP`      | Public IP of the Hetzner server        |

[actions]: https://github.com/features/actions
[closures]: https://zero-to-nix.com/concepts/closures
[detsys]: https://determinate.systems
[detsys-demo]: https://github.com/determinatesystems/demo
[cryptpad]: https://cryptpad.net
[fh]: https://github.com/determinatesystems/fh
[flakehub]: https://flakehub.com
[flakes]: https://zero-to-nix.com/concepts/flakes
[hetzner]: https://www.hetzner.com/cloud
[nix]: https://nixos.org
[nixos]: https://zero-to-nix.com/concepts/nixos
[nixos-hetzner]: https://github.com/outskirtslabs/nixos-hetzner
[opentofu]: https://opentofu.org
