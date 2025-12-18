# SSH key for deployments from GitHub Actions
resource "hcloud_ssh_key" "deploy" {
  name       = "flakehub-demo-deploy"
  public_key = var.deploy_ssh_public_key
}

# Optional: additional SSH key for manual access
resource "hcloud_ssh_key" "manual" {
  count      = var.ssh_public_key != "" ? 1 : 0
  name       = "flakehub-demo-manual"
  public_key = var.ssh_public_key
}

# Firewall allowing HTTP and SSH
resource "hcloud_firewall" "demo" {
  name = "flakehub-demo"

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
}

# The NixOS server
resource "hcloud_server" "demo" {
  name        = "flakehub-demo"
  server_type = var.server_type
  location    = var.location
  image       = var.hcloud_image_id

  ssh_keys = concat(
    [hcloud_ssh_key.deploy.id],
    hcloud_ssh_key.manual[*].id
  )

  firewall_ids = [hcloud_firewall.demo.id]

  # User data script runs on first boot
  # Authenticates with FlakeHub and applies the NixOS configuration
  user_data = <<-USERDATA
#!/bin/sh
set -e

# Wait for network
sleep 5

# Login to FlakeHub using token authentication
echo '${var.flakehub_token}' | determinate-nixd login token

# Apply the NixOS configuration from FlakeHub
fh apply nixos ${var.flake_reference}
USERDATA

  labels = {
    purpose = "flakehub-demo"
  }
}
