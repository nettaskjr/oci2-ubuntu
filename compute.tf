# Buscar a imagem Ubuntu mais recente para a arquitetura da instância (Aarch64 para A1.Flex)
data "oci_core_images" "ubuntu_images" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "ubuntu_instance" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = var.instance_display_name
  shape               = var.instance_shape

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_in_gbs
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
    display_name     = var.instance_display_name
    assign_public_ip = true
  }

  source_details {
    source_id               = data.oci_core_images.ubuntu_images.images[0].id
    source_type             = "image"
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
    # Cloud-Init Script para instalar e configurar Cloudflared
    user_data = base64encode(<<EOF
#cloud-config
package_update: true
packages:
  - curl
runcmd:
  - echo "Baixando Cloudflared..."
  # Download do recurso para ARM64 (Instância A1)
  - curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
  - dpkg -i cloudflared.deb
  - echo "Instalando servico Cloudflared com Token..."
  - cloudflared service install ${cloudflare_tunnel.auto_tunnel.tunnel_token}
EOF
    )
  }

  # Garantir que a instância seja criada apenas após a rede estar pronta (embora Terraform gerencie dependências, explícito ajuda as vezes)
  depends_on = [oci_core_subnet.public_subnet]
}

# Data source para obter Availability Domains (necessário para escolher onde criar a instância)
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}
