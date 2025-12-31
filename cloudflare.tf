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
    # Regra para ACESSO SSH (ex: ssh.seudominio.com)
    # Você deve ter um registro DNS apontando ssh.seudominio.com para esse túnel também (o wildcard cobre isso)
    ingress_rule {
      hostname = "ssh.${var.domain_name}"
      service  = "ssh://localhost:22"
    }

    # Regra para aplicação web principal (ex: seudominio.com)
    ingress_rule {
      hostname = var.domain_name
      service  = "http://localhost:80"
    }

    # Catch-all: qualquer outra coisa falha (obrigatório terminar com regra catch-all)
    ingress_rule {
      service = "http_status:404"
    }
  }
}
