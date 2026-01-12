resource "oci_core_vcn" "main_vcn" {
  compartment_id = var.compartment_ocid
  cidr_block     = "10.0.0.0/16"
  display_name   = var.instance_display_name
  dns_label      = "mainvcn"
}

resource "oci_core_internet_gateway" "main_ig" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main_vcn.id
  display_name   = "main-internet-gateway"
  enabled        = true
}

resource "oci_core_route_table" "main_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main_vcn.id
  display_name   = "main-route-table"

  route_rules {
    network_entity_id = oci_core_internet_gateway.main_ig.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}

resource "oci_core_security_list" "strict_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main_vcn.id
  display_name   = "strict-security-list"

  # Ingress: Bloquear todo o tráfego de entrada (Zero Trust via Cloudflare Tunnel)
  # Nenhuma regra de ingress é necessária pois a conexão é iniciada de dentro para fora (Egress)

  # DEBUG: SSH Temporário
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      max = 22
      min = 22
    }
    description = "DEBUG: Allow SSH access temporarily"
  }


  # Egress: Permitir todo tráfego de saída (necessário para o Cloudflared)
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "Allow all egress traffic"
  }
}

resource "oci_core_subnet" "public_subnet" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.main_vcn.id
  cidr_block        = "10.0.1.0/24"
  display_name      = "public-subnet"
  dns_label         = "public"
  route_table_id    = oci_core_route_table.main_rt.id
  security_list_ids = [oci_core_security_list.strict_sl.id]
}
