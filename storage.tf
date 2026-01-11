resource "oci_core_volume" "data_volume" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "${var.instance_display_name}-data-volume"
  size_in_gbs         = var.data_volume_size_in_gbs
  vpus_per_gb         = 10 # Balanced Performance

  # Trava de segurança: Impede que o Terraform destrua este volume, 
  # mesmo ao rodar 'terraform destroy'. Garante a persistência dos dados.
  # Caso queira destruir, mude para <<false>>, faca o apply para corrigir no estado
  # e depois o destroy.
  # Para destruir a infra sem destruir o volume, use:
  # terraform destroy -target=oci_core_instance.ubuntu_instance
  lifecycle {
    prevent_destroy = true
  }
}

resource "oci_core_volume_attachment" "data_volume_attachment" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.ubuntu_instance.id
  volume_id       = oci_core_volume.data_volume.id
  device          = "/dev/oracleoci/oraclevdb" # Device fixo OCI para paravirtualized (2º disco) atende como /dev/sdb no Linux
}
