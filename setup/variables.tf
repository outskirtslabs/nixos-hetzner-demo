variable "hcloud_token" {
  type        = string
  sensitive   = true
  description = "Hetzner Cloud API token"
}

variable "hcloud_image_id" {
  type        = number
  description = "ID of the uploaded NixOS image in Hetzner Cloud"
}

variable "ssh_public_key" {
  type        = string
  default     = ""
  description = "SSH public key for manual server access (optional)"
}

variable "deploy_ssh_public_key" {
  type        = string
  description = "SSH public key for GitHub Actions deployment"
}

variable "flake_reference" {
  type        = string
  description = "FlakeHub flake reference (e.g., outskirtslabs/nixos-hetzner-demo/0.1)"
}

variable "flakehub_token" {
  type        = string
  sensitive   = true
  description = "FlakeHub API token for determinate-nixd authentication"
}

variable "server_type" {
  type        = string
  default     = "cx22"
  description = "Hetzner Cloud server type (cx22 for x86, cax11 for arm)"
}

variable "location" {
  type        = string
  default     = "fsn1"
  description = "Hetzner Cloud datacenter location"
}
