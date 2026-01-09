#!/bin/bash
# OCI User Data Script
# Trocando de Cloud-Init YAML para Shell Script Bash puro para maior controle e legibilidade.

# Log de execução para debug
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Iniciando configuração da instância..."

# 1. Atualização e Instalação de Pacotes Básicos
apt-get update -y
apt-get install -y curl git xfsprogs

# 1.1 Configuração do Volume Persistente (Data Volume)
# OCI Paravirtualized attachment geralmente aparece como /dev/sdb se o boot for sda
DATA_DEVICE="/dev/sdb"
MOUNT_POINT="/var/lib/rancher"

echo "Configurando volume de dados persistente em $DATA_DEVICE..."

# Aguardar device aparecer
while [ ! -b $DATA_DEVICE ]; do echo "Aguardando disco $DATA_DEVICE..."; sleep 5; done

# Verificar se já está formatado (blkid retorna exit code 0 se tiver fs)
if ! blkid $DATA_DEVICE; then
    echo "Formatando $DATA_DEVICE como XFS..."
    mkfs.xfs $DATA_DEVICE
fi

# Criar mountpoint e montar
mkdir -p $MOUNT_POINT
echo "$DATA_DEVICE $MOUNT_POINT xfs defaults 0 0" >> /etc/fstab
mount -a
echo "Volume montado em $MOUNT_POINT"

# 2. Configuração de Firewall (Iptables)
# Limpar regras de firewall da Oracle (iptables) para permitir comunicação CNI
# Isso evita erros de "no route to host" entre Pods e API Server
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -F
netfilter-persistent save

# 3. Instalação e Configuração do Cloudflared
echo "Baixando e instalando o Cloudflared..."
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/download/${cloudflared_version}/cloudflared-linux-arm64.deb
dpkg -i cloudflared.deb
# O token é injetado via Terraform templatefile
cloudflared service install ${tunnel_token} 
systemctl daemon-reload
systemctl restart cloudflared

# 4. Instalação do K3s
export K3S_KUBECONFIG_MODE="644"
curl -sfL https://get.k3s.io | sh -

# Aguardar K3s API Server estar disponível
echo "Aguardando K3s API..."
until k3s kubectl get --raw='/readyz' > /dev/null 2>&1; do 
  sleep 2
done

# Aguardar Node ficar Ready (Melhor que sleep fixo)
echo "Aguardando Node ficar Ready..."
k3s kubectl wait --for=condition=Ready node --all --timeout=120s

# Aguardar CRDs do Traefik (Existence + Established)
echo "Aguardando Traefik CRDs..."
# Loop de existência (kubectl wait falha se objeto não existe)
until k3s kubectl get crd ingressroutes.traefik.io > /dev/null 2>&1; do 
  sleep 2
done
# Wait para garantir que o CRD está pronto para uso
k3s kubectl wait --for=condition=established crd/ingressroutes.traefik.io --timeout=60s

# 5. Configurar Kubeconfig para o usuário da instância (ubuntu)
USER_HOME="/home/${user_instance}"
mkdir -p $USER_HOME/.kube
cp /etc/rancher/k3s/k3s.yaml $USER_HOME/.kube/config
chown -R ${user_instance}:${user_instance} $USER_HOME/.kube
echo "export KUBECONFIG=$USER_HOME/.kube/config" >> $USER_HOME/.bashrc

# 6. GitOps: Clonar Repositório de Stack
STACK_DIR="$USER_HOME/.stack"
mkdir -p $STACK_DIR

if [ -n "${github_repo}" ]; then
  echo "Clonando repositório público: ${github_repo}"
  git clone "${github_repo}" $STACK_DIR
  
  # Substitui placeholders
  echo "Configurando variáveis nos manifestos..."
  find $STACK_DIR -name "*.yaml" -type f -exec sed -i "s|<<seu-dominio>>|${domain_name}|g" {} +
  find $STACK_DIR -name "*.yaml" -type f -exec sed -i "s|<<user-home>>|$USER_HOME|g" {} +
  
  chown -R ${user_instance}:${user_instance} $STACK_DIR
else
  echo "Nenhum repositório GitHub configurado."
fi

# 7. Aplicar Manifestos Kubernetes
if [ -d "$STACK_DIR" ]; then 
  echo "Aplicando manifestos Kubernetes..."
  # Aplicando em ordem específica
  kubectl apply -f $STACK_DIR/portainer.yaml
  
  # Aplicar monitoramento se existir
  if [ -d "$STACK_DIR/k8s-monitoring" ]; then
    kubectl apply -f $STACK_DIR/k8s-monitoring/
  fi
else 
  echo "Diretório .stack não encontrado!"
fi

# 8. Notificar Discord
if [ -n "${discord_webhook_url}" ]; then
  curl -H "Content-Type: application/json" \
  -d '{"content": "🚀 **Infra OCI Pronta!**\n- 🖥️ SSH: `ssh ssh.${domain_name}` (Zero Trust)\n- ☸️ Kubernetes: K3s Up\n- 🐳 Portainer: https://portainer.${domain_name}\n- 📊 Grafana: https://grafana.${domain_name}\n- 🔍 Loki Logs: Ativo\n\n_Deploy finalizado com sucesso!_"}' \
  "${discord_webhook_url}"
fi

echo "Configuração finalizada."
