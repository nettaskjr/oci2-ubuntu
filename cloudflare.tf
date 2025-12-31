resource "random_password" "tunnel_secret" {
  length  = 64
  special = false
}

resource "cloudflare_tunnel" "auto_tunnel" {
  account_id = var.cloudflare_account_id
  name       = "oci-ubuntu-tunnel-${var.instance_display_name}"
  secret     = base64sha256(random_password.tunnel_secret.result)
}


resource "cloudflare_record" "cname_wildcard" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  content = "${cloudflare_tunnel.auto_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "cname_root" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  content = "${cloudflare_tunnel.auto_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_tunnel_config" "auto_tunnel_config" {
  tunnel_id  = cloudflare_tunnel.auto_tunnel.id
  account_id = var.cloudflare_account_id

  config {
    # Regra para ACESSO SSH
    ingress_rule {
      hostname = "ssh.${var.domain_name}"
      service  = "ssh://localhost:22"
    }

    # Regra genérica para HTTP/HTTPS (Web)
    # Roteia tanto o domínio raiz quanto qualquer outro subdomínio (definido no DNS CNAME *) para o Traefik (localhost:80)
    # O Traefik fará o roteamento final baseado no Host header (ex: portainer.domain.com)
    ingress_rule {
      service = "http://localhost:80"
    }
  }
}
