# Variáveis PÚBLICAS para commit no repositório.
# NÃO coloque segredos, senhas ou chaves privadas aqui.
region                = "sa-saopaulo-1"
user_instance         = "ubuntu"
instance_display_name = "nettask-com-br"
cloudflare_zone_id    = "e48378dc6b5deb23ee5acbb9fa75b243" # Pegue no dashboard da Cloudflare, lado direito da pagina Overview
cloudflare_account_id = "d5aee7bff071474726766f0ee411b9b5" # Pegue no dashboard, mesmo lugar do Zone ID ou URL
domain_name           = "nettask.com.br"
state_bucket_name     = "terraform-state-nettask.com.br"
email                 = "nestor.junior@gmail.com"

# Nota: state_bucket_name aqui é apenas para a variável do Terraform. 
# A configuração do backend (terraform init) ainda precisará do nome do bucket via CLI ou configuração, 
# pois variáveis não funcionam no bloco backend. 

# Opcionais (Defaults já definidos)
# instance_shape           = "VM.Standard.A1.Flex"
# instance_ocpus           = 4
# instance_memory_in_gbs   = 24
# boot_volume_size_in_gbs  = 50
