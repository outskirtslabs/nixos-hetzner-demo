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

  labels = {
    purpose = "flakehub-demo"
  }
}

# Provision the server via SSH (NixOS doesn't have cloud-init by default)
resource "null_resource" "provision" {
  depends_on = [hcloud_server.demo]

  connection {
    type        = "ssh"
    user        = "root"
    private_key = var.deploy_ssh_private_key
    host        = hcloud_server.demo.ipv4_address
  }

  provisioner "remote-exec" {
    inline = [
      "echo '${var.flakehub_token}' > /tmp/fh-token",
      "determinate-nixd login token --token-file /tmp/fh-token",
      "rm /tmp/fh-token",
      "fh apply nixos ${var.flake_reference}"
    ]
  }
}
