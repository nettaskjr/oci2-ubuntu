# Variáveis PÚBLICAS para commit no repositório.
# NÃO coloque segredos, senhas ou chaves privadas aqui.

region                = "sa-saopaulo-1"
user_instance         = "ubuntu"
instance_display_name = "nettask.com.br"

# Defaults placeholders - Você deve alterar para seus valores reais se não for usar Secrets
# Como você removeu do Workflow, o Terraform precisará ler daqui ou de variáveis de ambiente locais.
domain_name       = "nettask.com.br"
state_bucket_name = "terraform-state-nettask.com.br"
email             = "nestor.junior@gmail.com"

# Nota: state_bucket_name aqui é apenas para a variável do Terraform. 
# A configuração do backend (terraform init) ainda precisará do nome do bucket via CLI ou configuração, 
# pois variáveis não funcionam no bloco backend. 
