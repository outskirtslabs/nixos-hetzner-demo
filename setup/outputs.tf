output "server_ip" {
  value       = hcloud_server.demo.ipv4_address
  description = "Public IPv4 address of the demo server"
}

output "server_ipv6" {
  value       = hcloud_server.demo.ipv6_address
  description = "Public IPv6 address of the demo server"
}

output "website" {
  value       = "http://${hcloud_server.demo.ipv4_address}"
  description = "URL of the EtherCalc demo"
}

output "ssh_command" {
  value       = "ssh root@${hcloud_server.demo.ipv4_address}"
  description = "SSH command to connect to the server"
}

output "flake_reference" {
  value       = var.flake_reference
  description = "FlakeHub flake reference used for deployment"
}
