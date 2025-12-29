terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 4.0.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    # Os detalhes do bucket devem ser passados via terraform init -backend-config=...
    # ou configurados aqui se o usuário preferir hardcoded (mas a boa prática e o request pedem via backend "s3")
    # Deixaremos a estrutura pronta. O usuário especificou que o bucket já existe.
    # Normalmente, precisa de bucket, key, region.
    # Como o request pede para configurar o bloco backend "s3" e usar var state_bucket_name (que não pode ser usada no bloco backend),
    # faremos uma configuração parcial ou assumiremos que o usuário vai preencher/injetar.
    # OBS: Variáveis não são permitidas dentro do bloco backend. 
    # O request diz: "O estado do Terraform (.tfstate) DEVE ser armazenado remotamente em um bucket AWS S3 existente. Configure o bloco backend "s3"."
    # Vou deixar o bloco configurado minimamente mas funcional para preenchimento ou via CLI.
    # key e region são obrigatórios para validação se não passados via CLI. 
    # Vou colocar placeholders comuns.

    key = "oci-infra/terraform.tfstate"
    # region = "us-east-1" # Exemplo, geralmente necessário
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.api_private_key_path
  region           = var.region
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
