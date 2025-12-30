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


#### Execução Local
1.  Exporte as credenciais AWS para o backend:
    ```bash
    export AWS_ACCESS_KEY_ID="xxx"
    export AWS_SECRET_ACCESS_KEY="xxx"
    export AWS_DEFAULT_REGION="us-east-1"
    ```
2.  Inicialize o Terraform:
    ```bash
    terraform init -backend-config="bucket=SEU_BUCKET" -backend-config="region=us-east-1"
    ```
3.  Planeje e Aplique:
    ```bash
    terraform apply
    ```

---

### 5. Pós-Deploy e Acesso
*   **Automação:** O script `user_data` (Cloud-Init) instalará automaticamente o agente `cloudflared` na instância.
*   **Acesso:** Aguarde alguns minutos após o provisionamento. O domínio configurado (ex: `nettask.com.br` ou subdomínio) estará acessível via HTTPS, roteado pelo tunel da Cloudflare direto para sua instância, protegendo seu IP de origem.
*   **SSH:** Para acessar a máquina:
    ```bash
    ssh -i /caminho/para/chave_privada ubuntu@<IP_PUBLICO_OUTPUT>
    ```

### Estrutura de Arquivos Importantes
*   `providers.tf`: Configuração dos provedores e backend S3.
*   `network.tf`: VCN e Firewall (Bloqueia tudo, libera apenas SSH e Egress).
*   `compute.tf`: Instância A1 (ARM64) com script de boot.
*   `cloudflare.tf`: Criação do Túnel Zero Trust e DNS.