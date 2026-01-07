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
  - git
runcmd:
  # Limpar regras de firewall da Oracle (iptables) para permitir comunicação CNI
  # Isso evita erros de "no route to host" entre Pods e API Server
  - iptables -P INPUT ACCEPT
  - iptables -P FORWARD ACCEPT
  - iptables -P OUTPUT ACCEPT
  - iptables -F
  - netfilter-persistent save
  
  # Cloudflared (Configuração existente)
  - echo "Baixando e instalando o Cloudflared..."
  - curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
  - dpkg -i cloudflared.deb
  - cloudflared service install ${cloudflare_tunnel.auto_tunnel.tunnel_token} 
  - systemctl daemon-reload
  - systemctl restart cloudflared

  # Notificar Discord (se a URL estiver configurada)
  - |
    if [ -n "${var.discord_webhook_url}" ]; then
      curl -H "Content-Type: application/json" \
      -d '{"content": "🖥️ SSH disponível: `ssh ssh.${var.domain_name}` (Zero Trust)"}' \
      "${var.discord_webhook_url}"
    fi
 
  # Instalação K3s (vamos manter o traefik default)
  - curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
  
  # Aguardar K3s iniciar o Node
  - until k3s kubectl get node; do echo "Aguardando K3s Node..."; sleep 5; done
  
  # Aguardar CRDs do Traefik (race condition check)
  # Isso garante que kind: IngressRoute seja reconhecido antes de aplicar os yamls
  - until k3s kubectl get crd ingressroutes.traefik.io > /dev/null 2>&1; do echo "Aguardando Traefik CRDs..."; sleep 5; done

  # Configurar Kubeconfig para usuário local
  - mkdir -p /home/${var.user_instance}/.kube
  - cp /etc/rancher/k3s/k3s.yaml /home/${var.user_instance}/.kube/config
  - chown -R ${var.user_instance}:${var.user_instance} /home/${var.user_instance}/.kube
  - echo "export KUBECONFIG=/home/${var.user_instance}/.kube/config" >> /home/${var.user_instance}/.bashrc

  # Clonando repositório de Stack (Arquivos YAML)
  # Executando como um bloco de script único para evitar erros de sintaxe YAML
  - |
    set -x # Habilita log detalhado de execução
    mkdir -p /home/${var.user_instance}/.stack
    if [ -n "${var.github_repo}" ]; then
      echo "Clonando repositório público: ${var.github_repo}"
     
      # Clona para pasta .stack
      git clone "${var.github_repo}" /home/${var.user_instance}/.stack
      
      # Substitui placeholders de domínio nos arquivos YAML
      find /home/${var.user_instance}/.stack -name "*.yaml" -type f -exec sed -i "s|<<seu-dominio>>|${var.domain_name}|g" {} +
      
      chown -R ${var.user_instance}:${var.user_instance} /home/${var.user_instance}/.stack
      echo "Repositório clonado com sucesso!"
    else
      echo "Nenhum repositório GitHub configurado."
    fi

  ## Instalar Manifestos Kubernetes (Portainer + Monitoring Stack)
  ## O kubectl apply -R (recursivo) aplicará tudo que estiver dentro de .stack/
  ## Isso inclui portainer.yaml e a pasta k8s-monitoring/ se ela existir no repo
  #- if [ -d /home/${var.user_instance}/.stack ]; then 
  #    echo "Aplicando manifestos Kubernetes..."
  #    kubectl apply -R -f /home/${var.user_instance}/.stack/
  #  else 
  #    echo "Diretório .stack não encontrado!"
  #  fi

  # Aplicar manifestos Kubernetes (Portainer + Monitoring Stack)
  # Vamos aplicar os manifestos 1 a 1 para evitar erros de sintaxe YAML,
  # e para que nao executemos todos os arquivos do repositório de uma vez
  - |
    set -x # Habilita log detalhado
    if [ -d /home/${var.user_instance}/.stack ]; then 
      echo "Aplicando manifestos Kubernetes..."
      kubectl apply -f /home/${var.user_instance}/.stack/portainer.yaml
      kubectl apply -f /home/${var.user_instance}/.stack/k8s-monitoring/00-namespace.yaml
      kubectl apply -f /home/${var.user_instance}/.stack/k8s-monitoring/01-loki.yaml
      kubectl apply -f /home/${var.user_instance}/.stack/k8s-monitoring/02-promtail.yaml
      kubectl apply -f /home/${var.user_instance}/.stack/k8s-monitoring/03-prometheus-rbac.yaml
      kubectl apply -f /home/${var.user_instance}/.stack/k8s-monitoring/04-prometheus-config.yaml
      kubectl apply -f /home/${var.user_instance}/.stack/k8s-monitoring/05-prometheus-deployment.yaml
      kubectl apply -f /home/${var.user_instance}/.stack/k8s-monitoring/06-grafana-datasource.yaml
      kubectl apply -f /home/${var.user_instance}/.stack/k8s-monitoring/07-grafana-deployment.yaml
      kubectl apply -f /home/${var.user_instance}/.stack/k8s-monitoring/08-grafana-dashboard-provider.yaml
    else 
      echo "Diretório .stack não encontrado!"
    fi

  # Notificar Discord (se a URL estiver configurada)
  - |
    if [ -n "${var.discord_webhook_url}" ]; then
      curl -H "Content-Type: application/json" \
      -d '{"content": "🚀 **Infra OCI Pronta!**\n- 🖥️ SSH: `ssh ssh.${var.domain_name}` (Zero Trust)\n- ☸️ Kubernetes: K3s Up\n- 🐳 Portainer: https://portainer.${var.domain_name}\n- 📊 Grafana: https://grafana.${var.domain_name}\n- 🔍 Loki Logs: Ativo\n\n_Deploy finalizado com sucesso!_"}' \
      "${var.discord_webhook_url}"
    fi

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
