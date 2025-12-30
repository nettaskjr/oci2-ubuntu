resource "random_password" "tunnel_secret" {
  length  = 64
  special = false
}

resource "cloudflare_tunnel" "auto_tunnel" {
  account_id = var.cloudflare_account_id
  name       = "oci-ubuntu-tunnel-${var.instance_display_name}"
  secret     = base64sha256(random_password.tunnel_secret.result)
}


resource "cloudflare_record" "cname_tunnel" {
  zone_id = var.cloudflare_zone_id # Usando ID explícito fornecido pelo usuário
  name    = var.domain_name
  # O valor deve ser o endereço do túnel
  content = "${cloudflare_tunnel.auto_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}
