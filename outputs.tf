output "instance_public_ip" {
  description = "IP Público da instância criada na OCI"
  value       = oci_core_instance.ubuntu_instance.public_ip
}

output "tunnel_token" {
  description = "Token do Túnel Cloudflare (use para configurar cloudflared na VM)"
  value       = cloudflare_tunnel.auto_tunnel.tunnel_token
  sensitive   = true
}

output "tunnel_id" {
  description = "ID do Túnel Cloudflare"
  value       = cloudflare_tunnel.auto_tunnel.id
}

output "tunnel_cname" {
  description = "Endereço CNAME do Túnel"
  value       = "${cloudflare_tunnel.auto_tunnel.id}.cfargotunnel.com"
}
