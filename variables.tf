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
}

variable "instance_ocpus" {
  description = "Número de OCPUs da instância Flex"
  type        = number
  default     = 4
}

variable "instance_memory_in_gbs" {
  description = "Memória em GBs da instância Flex"
  type        = number
  default     = 24
}

variable "boot_volume_size_in_gbs" {
  description = "Tamanho do volume de boot em GBs"
  type        = number
  default     = 50
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


