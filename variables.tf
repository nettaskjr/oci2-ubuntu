variable "tenancy_ocid" {
  description = "OCID do Tenancy"
  type        = string
}

variable "user_ocid" {
  description = "OCID do Usuário"
  type        = string
}

variable "compartment_ocid" {
  description = "OCID do Compartimento"
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint da chave API"
  type        = string
}

variable "region" {
  description = "Região da OCI (ex: sa-saopaulo-1)"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Caminho para o arquivo da chave pública SSH"
  type        = string
}

variable "api_private_key_path" {
  description = "Caminho para o arquivo da chave privada da API OCI"
  type        = string
}

variable "user_instance" {
  description = "Usuário padrão da instância"
  type        = string
  default     = "ubuntu"
}

variable "instance_display_name" {
  description = "Nome de exibição da instância"
  type        = string
}

variable "instance_shape" {
  description = "Shape da instância"
  type        = string
  default     = "VM.Standard.A1.Flex"

  validation {
    condition     = can(regex("Flex", var.instance_shape))
    error_message = "O shape da instância deve ser do tipo Flex (ex: VM.Standard.A1.Flex) para suportar configuração personalizada de OCPU e Memória."
  }
}

variable "instance_ocpus" {
  description = "Número de OCPUs da instância Flex"
  type        = number
  default     = 4

  validation {
    condition     = var.instance_ocpus > 0
    error_message = "O número de OCPUs deve ser maior que 0."
  }
}

variable "instance_memory_in_gbs" {
  description = "Memória em GBs da instância Flex"
  type        = number
  default     = 24

  validation {
    condition     = var.instance_memory_in_gbs > 0
    error_message = "A memória RAM deve ser maior que 0 GB."
  }
}

variable "boot_volume_size_in_gbs" {
  description = "Tamanho do volume de boot em GBs"
  type        = number
  default     = 50

  validation {
    condition     = var.boot_volume_size_in_gbs >= 50
    error_message = "O volume de boot deve ter no mínimo 50 GB para acomodar o OS e as aplicações."
  }
}

variable "cloudflare_api_token" {
  description = "Token da API do Cloudflare"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "ID da Zona no Cloudflare (Zone ID) onde o DNS será criado"
  type        = string
}

variable "cloudflare_account_id" {
  description = "ID da Conta do Cloudflare (Account ID)"
  type        = string
}

variable "domain_name" {
  description = "Nome de domínio para o túnel (ex: app.exemplo.com)"
  type        = string
}

variable "state_bucket_name" {
  description = "Nome do bucket S3 para backend"
  type        = string
}

variable "github_repo" {
  description = "URL do repositório para clonar (ex: https://github.com/usuario/repo.git). Use HTTPS."
  type        = string
}

variable "discord_webhook_url" {
  description = "URL do Webhook do Discord para notificações de deploy"
  type        = string
  sensitive   = true
  default     = "" # Opcional, se vazio não envia
}

variable "cloudflared_version" {
  description = "Versão do Cloudflared a ser instalada (evita quebra por updates automáticos)"
  type        = string
  default     = "2024.1.5"
}

variable "data_volume_size_in_gbs" {
  description = "Tamanho do volume de dados persistentes (Block Volume) em GBs"
  type        = number
  default     = 50

  validation {
    condition     = var.data_volume_size_in_gbs >= 50
    error_message = "O volume de dados deve ter no mínimo 50 GB."
  }
}
