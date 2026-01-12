# OCI Ubuntu Infra + Cloudflare Zero Trust

Este projeto provisiona uma infraestrutura na **Oracle Cloud Infrastructure (OCI)** utilizando **Terraform**. Ele cria uma instância Compute (Ubuntu/ARM) e expõe aplicações de forma segura através de um **Cloudflare Tunnel**, sem a necessidade de abrir portas de entrada no firewall (apenas saída).

## 📋 Pré-requisitos
*   Nova conta ou Tenancy na **Oracle Cloud**.
*   Conta na **Cloudflare** com um domínio ativo.
*   Conta na **AWS** (para armazenar o estado do Terraform no S3).
*   Repositório no **GitHub**.

---

## 🚀 Passo a Passo de Configuração

### 1. Preparando o Backend AWS (S3 + IAM)
O Terraform precisa guardar o arquivo de estado (`.tfstate`) em um local seguro. Usaremos um Bucket S3 para isso.

#### Criar o Bucket S3
1.  Acesse o Console da AWS > **S3**.
2.  Clique em **Create bucket**.
3.  **Name:** Escolha um nome único (ex: `terraform-state-nettask.com.br`).
4.  **Region:** `us-east-1` (N. Virgínia).
5.  **Block Public Access:** ☑️ Marque **"Block all public access"** (Crítico!).
6.  **Versioning:** ☑️ **Enable** (Recomendado para backup do estado).
7.  Clique em **Create bucket**.

#### Criar Usuário IAM (Chaves de Acesso)
1.  Acesse Console AWS > **IAM**.
2.  Vá em **Users** > **Create user** (ex: `terraform-bot`).
3.  Anexe uma política (**Attach policies directly**) ou crie uma política inline JSON com permissão mínima ao bucket:
    ```json
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
                "Resource": ["arn:aws:s3:::SEU_BUCKET_NAME", "arn:aws:s3:::SEU_BUCKET_NAME/*"]
            }
        ]
    }
    ```
4.  Após criar, vá na aba **Security credentials** do usuário.
5.  Crie uma **Access Key** (tipo CLI).
6.  **GUARDE:** O `Access Key ID` e o `Secret Access Key`. Você não verá o Secret novamente.

---

### 2. Configurando o GitHub (Secrets e Variáveis)

Para que a automação (`.github/workflows/terraform.yml`) funcione, você precisa cadastrar os segredos no repositório.

Vá em **Settings** > **Secrets and variables** > **Actions** > **New repository secret**.

#### Secrets Obrigatórios
| Secret | Descrição | Onde conseguir |
| :--- | :--- | :--- |
| `AWS_ACCESS_KEY_ID` | Chave de acesso do usuário IAM | Console AWS |
| `AWS_SECRET_ACCESS_KEY` | Segredo da chave IAM | Console AWS |
| `OCI_TENANCY_OCID` | ID do Tenancy | Console OCI (Perfil > Tenancy) |
| `OCI_USER_OCID` | ID do Usuário OCI | Console OCI (Identity > Users) |
| `OCI_FINGERPRINT` | Fingerprint da chave API OCI | Console OCI (Users > API Keys) |
| `OCI_PRIVATE_KEY_PEM` | Conteúdo da chave privada `.pem` | Sua chave local gerada para API OCI |
| `CLOUDFLARE_API_TOKEN` | Token da API Cloudflare | Dash Cloudflare (Profile > API Tokens) |
| `OCI_COMPARTMENT_OCID` | ID do Compartimento | Console OCI (Identity > Compartments) |
| `TF_STATE_BUCKET_NAME`| Nome do bucket S3 criado | Ex: `terraform-state-nettask.com.br` |

> **Dica:** O Token da Cloudflare precisa das permissões: *Zone:Properties (Read)*, *Account:Tunnel (Read/Write)* e *DNS (Read/Write)*.

---

### 3. Configuração do Código

#### Variáveis Públicas (`terraform.auto.tfvars`)
Edite o arquivo `terraform.auto.tfvars` na raiz do projeto. Estas variáveis **não são secretas** e devem ser commitadas no repositório.

```hcl
region            = "sa-saopaulo-1"
domain_name       = "nettask.com.br"
cloudflare_zone_id = "xxx..." 
cloudflare_account_id = "xxx..." # ID da Conta (Account ID)
email             = "seu@email.com"
state_bucket_name = "terraform-state-nettask.com.br" # Apenas referência para variável, o backend usa a config do init
```

#### Variáveis Locais (`terraform.tfvars`)
**Apenas para uso local**. Este arquivo é ignorado pelo Git (`.gitignore`) para sua segurança.
Renomeie `terraform.tfvars.example` para `terraform.tfvars` e preencha se for rodar comandos `terraform` no seu computador.

---

### 4. Execução e Deploy

#### Via GitHub Actions (Recomendado)
Apenas faça um **Push** na branch `main`.
1.  O fluxo irá validar o código.
2.  Se for um Pull Request, fará um `terraform plan` (previsão).
3.  Ao mergear na `main`, fará o `terraform apply`.

#### Gerenciamento Manual e Destroy
O workflow foi configurado com `workflow_dispatch`, permitindo execução manual:
1.  Vá na aba **Actions** do GitHub.
2.  Selecione o workflow **Terraform Infrastructure**.
3.  Clique em **Run workflow**.
4.  No dropdown "Ação do Terraform", escolha:
    *   **apply**: Para criar/atualizar.
    *   **destroy**: Para DESTRUIR toda a infraestrutura (Cuidado!).



### 5. Configuração de Notificações (Discord)

Para receber alertas de deploy e status de restart, configure um **Webhook** no Discord:
1. No seu servidor Discord, vá em Editar Canal > Integrações > Webhooks > Novo Webhook.
2. Copie a URL.
3. Adicione o Secret no GitHub: `DISCORD_WEBHOOK_URL`
4. *(Opcional)* Adicione no `terraform.tfvars` local para testes manuais.

#### Tabela Atualizada de Secrets (GitHub Actions)
Adicione estes segredos além dos listados acima:

| Secret | Descrição |
| :--- | :--- |
| `DISCORD_WEBHOOK_URL`| URL do Webhook Discord para notificações |
| `SSH_PUBLIC_KEY` | Conteúdo da sua chave pública SSH (para injetar na instância) |
| `OCI_REGION` | Região da OCI (ex: `sa-saopaulo-1`) para o workflow de Restart |

---

### 6. Observabilidade e Monitoramento 📊

Esta infraestrutura já nasce com uma stack completa de monitoramento baseada em Prometheus e Grafana.

**Componentes Instalados (namespace `monitoring`):**
*   **Prometheus:** Coletor de métricas.
*   **Loki:** Agregador de Logs.
*   **Promtail:** Agente que envia logs dos containers para o Loki.
*   **Node Exporter:** Métricas de hardware/SO do host.
*   **Kube-State-Metrics:** Métricas do estado do cluster Kubernetes.

*   **Grafana:** Visualização.

> **Nota:** Todos os serviços de monitoramento foram configurados com **Health Probes** (Liveness/Readiness) e **Resource Limits** (CPU/Memória) para garantir estabilidade e evitar "Noisy Neighbor".

**Acesso:**
*   **URL:** `https://grafana.seu-dominio.com.br`
*   **Credenciais Padrão:** `admin` / `admin` (Altere no primeiro login!)

**Dashboards Pré-Instalados:**
1.  **Kubernetes Cluster (ID 15757):** Visão geral de CPU/Memória/Pods do cluster.
2.  **Node Exporter Full (ID 1860):** Detalhes profundos do servidor Linux (Rede/Disco/IO).
3.  **Loki Kubernetes Logs (ID 13639):** Explorador de logs centralizado com busca.

---

### 7. Pós-Deploy e Acesso Zero Trust

*   **Automação:** O script de inicialização (`scripts/user_data.sh`) é injetado via `compute.tf` e instala automaticamente:
    *   `cloudflared` (Túnel) com fallback automático
    *   Setup de Storage Persistente (Volume OCI => `/var/lib/rancher`)
    *   `k3s` (Kubernetes)
    *   Stack de Monitoramento
    *   Portainer
*   **Logs de Instalação:** Para debugar o processo de inicialização, consulte o log na instância:
    ```bash
    tail -f /var/log/user-data.log
    ```
*   **SSH Seguro:** O acesso SSH direto (porta 22 pública) foi removido. O acesso agora é via Cloudflare Tunnel:
    ```bash
    ssh ssh.seu-dominio.com.br
    ```

### 8. Operações "Day 2" (Manutenção)

#### Reiniciar Instância OCI
Se precisar reiniciar o servidor (travamento, kernel update), não use o painel da Oracle. Use o GitHub Actions:
1. Vá na aba **Actions** > **Restart OCI Instance**.
2. Clique em **Run workflow**.
3. O workflow irá autenticar na OCI CLI e emitir um `SOFTRESET`.
4. Você será notificado no Discord sobre o sucesso/falha.

#### Destruir Infraestrutura
Use o workflow **Terraform Infrastructure** com a opção `destroy`.

---

### Estrutura de Arquivos Importantes
*   `providers.tf`: Configuração dos provedores e backend S3.
*   `network.tf`: VCN e Firewall (Bloqueia tudo, libera apenas Egress e subrede interna).
*   `compute.tf`: Instância (ARM64) + Chamada para o script de boot.
*   `scripts/user_data.sh`: Script BASH mestre de instalação (Executado no primeiro boot).
*   `storage.tf`: Configuração do Block Volume persistente (montado em `/var/lib/rancher`).
*   `cloudflare.tf`: Criação do Túnel Zero Trust e DNS.
*   `k8s-monitoring/*.yaml`: Manifestos da stack de observabilidade.

---

## ⚡ Cheat Sheet: Comandos Úteis

Um resumo rápido dos comandos que você mais usará no dia a dia.

| Categoria | Comando | Descrição |
|-----------|---------|-----------|
| **Geral** | `kubectl get pods -A` | Lista todos os pods de todos os namespaces. |
| **Geral** | `kubectl get svc -A` | Lista todos os serviços (IPs e Portas). |
| **Geral** | `kubectl get ing -A` | Lista todas as regras de Ingress (domínios configurados). |
| **Logs** | `kubectl logs -f [POD] -n [NS]` | Acompanha os logs de um pod em tempo real. |
| **Debug** | `kubectl describe pod [POD] -n [NS]` | Mostra detalhes profundos e erros de um pod. |
| **Debug** | `kubectl delete pod [POD] -n [NS]` | Exclui (e re-cria) um pod travado. |
| **Monitoramento** | `kubectl get pods -n monitoring` | Verifica a saúde da stack Prometheus/Grafana. |
| **Portainer** | `kubectl rollout restart deploy portainer -n portainer` | Reinicia o Portainer (útil para erro de timeout de admin). |
| **Cloudflare** | `kubectl logs -l app=cloudflared -n kube-system` | Vê os logs do túnel (conexão com a Cloudflare). |
| **K8s** | `kubectl get nodes` | Verifica os nós do cluster Kubernetes. |
| **K8s** | `sudo systemctl restart k3s` | Reinicia o cluster Kubernetes. |

---
