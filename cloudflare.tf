resource "random_password" "tunnel_secret" {
  length  = 64
  special = false
}

# Data source para buscar contas (necessário para o account_id do túnel)
data "cloudflare_accounts" "my_accounts" {
}

# Lógica local para extrair o nome da zona a partir do domain_name
locals {
  # Tenta extrair dominio.com de app.dominio.com ou usa o próprio domínio se não houver subdomínio aparente
  # Esta é uma lógica simplificada. O ideal seria o usuário fornecer a Zone ID explicitamente, mas estamos restritos às variáveis.
  domain_parts = split(".", var.domain_name)
  # Se houver mais de 2 partes (ex: a.b.com), pega as 2 últimas (b.com). Se for b.com, pega b.com.
  zone_name_inferred = length(local.domain_parts) > 1 ? join(".", slice(local.domain_parts, length(local.domain_parts) - 2, length(local.domain_parts))) : var.domain_name
}

# Data source para buscar a Zone ID baseada no nome inferido
data "cloudflare_zone" "my_zone" {
  name = local.zone_name_inferred
  # account_id removido pois não é suportado neste data source na v4 desta maneira ou é desnecessário com o provider configurado com token
}


resource "cloudflare_tunnel" "auto_tunnel" {
  # account_id - O provider requer account_id. Usamos o da primeira conta encontrada.
  account_id = data.cloudflare_accounts.my_accounts.accounts[0].id
  name       = "oci-ubuntu-tunnel-${var.instance_display_name}"
  secret     = base64sha256(random_password.tunnel_secret.result)
}


resource "cloudflare_record" "cname_tunnel" {
  zone_id = data.cloudflare_zone.my_zone.id
  name    = var.domain_name
  # O valor deve ser o endereço do túnel
  value   = "${cloudflare_tunnel.auto_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}
