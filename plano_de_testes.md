# Plano de Testes Integrado (Infra & Apps)

Este documento descreve o roteiro de testes para validar a infraestrutura na OCI, a segurança do túnel Cloudflare e o funcionamento da stack de observabilidade.

## 1. Acesso e Conectividade (Zero Trust) ✅

Objetivo: Garantir que o acesso seja feito **apenas** através do túnel seguro e que a instância não esteja exposta diretamente à internet.

| ID  | Teste | Comando / Ação | Resultado Esperado |
| :--- | :--- | :--- | :--- |
| **A1** | **Acesso SSH via Túnel** | `ssh ubuntu@ssh.nettask.com.br` | Conexão bem-sucedida sem senha (se chave SSH configurada) ou prompt. |
| **A2** | **Bloqueio de SSH Direto** | `ssh ubuntu@<IP_PUBLICO_DA_INSTANCIA>` | **Timeout** ou Connection Refused. (A porta 22 não deve estar aberta na VCN). |
| **A3** | **Acesso Web Grafana** | Navegador: `https://grafana.nettask.com.br` | Carregar tela de login do Grafana (SSL válido). |
| **A4** | **Acesso Web Portainer** | Navegador: `https://portainer.nettask.com.br` | Carregar tela de setup/login do Portainer. |
| **A5** | **Resolução DNS** | `nslookup ssh.nettask.com.br` | Deve retornar endereços da Cloudflare, **não** o IP da Oracle. |

## 2. Segurança e Vulnerabilidades 🛡️

Objetivo: Validar o "hardering" da instância e do cluster.

| ID  | Teste | Comando / Ação | Resultado Esperado |
| :--- | :--- | :--- | :--- |
| **B1** | **Port Scan Externo** | `nmap -Pn <IP_PUBLICO_DA_INSTANCIA>` | **Nenhuma porta aberta** (All ports filtered). A instância deve ser "invisível". |
| **B2** | **Firewall Interno (Iptables)** | (No servidor) `sudo iptables -L` | Verificar se as regras permitem tráfego CNI (Kubernetes) e bloqueiam entrada externa indesejada. |
| **B3** | **Permissões de Arquivos** | (No servidor) `ls -l /etc/rancher/k3s/k3s.yaml` | Apenas root (600 ou 644) deve ter acesso de escrita. |
| **B4** | **Segredos em Texto Plano** | Verificar logs do Cloud-Init `/var/log/user-data.log` | Tokens e senhas não devem aparecer nos logs (exceto se debugging estiver ligado explicitamente). |

## 3. Execução e Integridade (Runtime) ⚙️

Objetivo: Garantir que os serviços iniciaram e estão saudáveis.

| ID  | Teste | Comando / Ação | Resultado Esperado |
| :--- | :--- | :--- | :--- |
| **C1** | **Status do Node K3s** | `kubectl get nodes` | Status **Ready**. |
| **C2** | **Deployments Monitoring** | `kubectl get pods -n monitoring` | Todos os pods (Grafana, Prometheus, Loki, Promtail) com status **Running** e **0 Restarts** (inicialmente). |
| **C3** | **Logs de Instalação** | `cat /var/log/user-data.log` | Log deve terminar com "Configuração finalizada." e mensagem de sucesso. |
| **C4** | **Cloudflared Service** | `systemctl status cloudflared` | Status **Active (running)**. |

## 4. Observabilidade e Funcionalidade 📊

Objetivo: Validar se os dados estão fluindo (Metrics & Logs).

| ID  | Teste | Comando / Ação | Resultado Esperado |
| :--- | :--- | :--- | :--- |
| **D1** | **Targets do Prometheus** | Grafana > Explore > Prometheus | Query `up{job="kubernetes-nodes"}` deve retornar valor 1. |
| **D2** | **Ingestão de Logs (Loki)** | Grafana > Explore > Loki | Query `{namespace="monitoring"}` deve mostrar logs recentes dos pods. |
| **D3** | **Persistência de Dados** | Reiniciar Pod Prometheus (`kubectl delete pod ...`) | Após reiniciar, o histórico de métricas deve permanecer visível no Grafana. |
| **D4** | **Resiliência (Probes)** | (Simulação) Matar processo do Grafana dentro do container | O Kubernetes deve detectar (Liveness Probe falha) e reiniciar o pod automaticamente. |

## 5. Testes de Ciclo de Vida (Day 2) 🔄

| ID  | Teste | Comando / Ação | Resultado Esperado |
| :--- | :--- | :--- | :--- |
| **E1** | **Reiniciar Instância** | Executar Action GitHub "Restart OCI Instance" | A instância OCI reinicia, e após ~2 min o acesso SSH e Grafana voltam automaticamente. |
| **E2** | **Redeploy via Terraform** | Alterar uma Label no Terraform e rodar Apply | O Terraform deve detectar a mudança e aplicar sem destruir a instância (se possível). |
