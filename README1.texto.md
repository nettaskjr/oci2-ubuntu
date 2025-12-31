# 🚀 Infraestrutura Moderna: OCI + Kubernetes + Portainer + Traefik + Cloudflare Tunnel

Este é um guia técnico avançado para configurar uma infraestrutura moderna, focada em **segurança (Zero Trust)** e **escalabilidade**, utilizando uma instância Oracle Cloud (OCI).

Utilizaremos o **K3s** (uma distribuição Kubernetes leve e certificada, ideal para instâncias cloud), desabilitaremos o Traefik padrão para instalar uma versão limpa via Helm, subiremos o **Portainer** e conectaremos tudo via **Cloudflare Tunnel**.

---

## 📋 Tabela de Conteúdos
- [Pré-requisitos](#pré-requisitos)
- [Passo 1: Preparação do Sistema Operacional](#passo-1-preparação-do-sistema-operacional)
- [Passo 1.5: Clonando o Repositório](#passo-15-clonando-o-repositório)
- [Passo 2: Instalação do Kubernetes (K3s)](#passo-2-instalação-do-kubernetes-k3s)
- [Passo 3: Instalação do Helm](#passo-3-instalação-do-helm)
- [Passo 4: Instalação do Traefik (Ingress Controller)](#passo-4-instalação-do-traefik-ingress-controller)
- [Passo 5: Instalação do Portainer](#passo-5-instalação-do-portainer)
- [Passo 6: Configuração do Cloudflare Tunnel (Zero Trust)](#passo-6-configuração-do-cloudflare-tunnel-zero-trust)
- [Passo 7: Expondo o Portainer via Ingress](#passo-7-expondo-o-portainer-via-ingress)
- [Passo 8: Configuração de Monitoramento (Loki, Prometheus, Grafana)](#passo-8-configuração-de-monitoramento-loki-prometheus-grafana)
- [Passo 9: Validação Final e Testes](#passo-9-validação-final-e-testes)
- [Passo 10: Teste Real](#passo-10-teste-real)
- [Passo 11: Possíveis Problemas](#passo-11-possíveis-problemas)
- [Resumo da Arquitetura](#resumo-da-arquitetura)

---

## ✅ Pré-requisitos

Antes de começar, certifique-se de ter:
- 🌐 Domínio gerenciado pela Cloudflare.
- 🔑 Acesso SSH à instância OCI (como root ou usuário com sudo).
- 🔒 Conta no Cloudflare Zero Trust (Grátis).

---

## 🛠️ Passo 1: Preparação do Sistema Operacional

Primeiro, vamos garantir que o sistema (Oracle Linux ou Ubuntu) esteja atualizado e com as dependências básicas.

```bash
# Atualizar pacotes
sudo apt update && sudo apt upgrade -y  # Se for Ubuntu
# sudo dnf update -y                    # Se for Oracle Linux

# Instalar utilitários essenciais
sudo apt install -y curl git unzip      # Ubuntu
# sudo dnf install -y curl git unzip    # Oracle Linux
```

---

## 📂 Passo 1.5: Clonando o Repositório

> **IMPORTANTE:** Todos os passos deste guia devem ser executados dentro da sua instância OCI, via SSH.

Agora, clone este repositório para ter acesso aos arquivos de configuração (pasta `yaml`).

```bash
# Clone o repositório (ajuste a URL se necessário)
git clone https://github.com/seu-usuario/seu-repo.git infra-oci

# Entre na pasta do projeto
cd infra-oci
```

---

## ☸️ Passo 2: Instalação do Kubernetes (K3s)

Instalaremos o K3s desabilitando o Traefik padrão. Faremos isso para instalar o Traefik separadamente via Helm depois, garantindo controle total sobre as configurações de Ingress.

```bash
# Instala o K3s sem o Traefik nativo
curl -sfL https://get.k3s.io | sh -s - --disable traefik

# Configura permissões para usar o kubectl sem sudo (opcional, mas recomendado)
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
echo "export KUBECONFIG=~/.kube/config" >> ~/.bashrc
source ~/.bashrc

# Verifica se os nós estão rodando
kubectl get nodes
```

---

## ⚓ Passo 3: Instalação do Helm

O Helm é o gerenciador de pacotes do Kubernetes.

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

---

## 🌐 Passo 4: Instalação do Traefik (Ingress Controller)

Agora instalaremos o Traefik oficial.

```bash
# Adiciona o repositório Helm
helm repo add traefik https://traefik.github.io/charts
helm repo update

# Cria o namespace e instala
kubectl create namespace traefik
helm install traefik traefik/traefik -n traefik \
  --set service.type=ClusterIP \
  --set ingressClass.enabled=true \
  --set ingressClass.isDefaultClass=true
```

> **Nota:** Usamos `ClusterIP` porque o Cloudflare Tunnel acessará o serviço internamente, não precisamos expor portas NodePort ou LoadBalancer para a internet pública.

---

## 🖥️ Passo 5: Instalação do Portainer

Vamos instalar a interface de gestão.

```bash
helm repo add portainer https://portainer.github.io/k8s/
helm repo update

kubectl create namespace portainer
helm install portainer portainer/portainer \
  --namespace portainer \
  --set service.type=ClusterIP
```

---

## 🔒 Passo 6: Configuração do Cloudflare Tunnel (Zero Trust)

Esta é a parte mágica. Não abriremos portas 80/443 na Oracle. O tráfego entrará por um túnel criptografado.

1. Acesse o painel **Cloudflare Zero Trust (https://one.dash.cloudflare.com/)** > **Networks** > **Manage Tunnels**.
2. Clique em **Add a Tunnel** na caixa **Create a new cloudflared Tunnel**.
3. Dê um nome (ex: `oci-k8s`), clique em **Save Tunnel** e aguarde.
4. **Importante:** Na tela de instalação, copie o token gerado (parece com `eyJhIjoi...`), clique em **Next**.

No terminal, edite o arquivo `yaml/cloudflared.yaml` usando seu editor preferido (ex: `nano` ou `vi`) e insira o token que você copiou (substitua `seu token aqui`).

```bash
nano yaml/cloudflared.yaml
```

Em seguida, aplique o arquivo:

```bash
kubectl apply -f yaml/cloudflared.yaml
```

### Configurando o Roteamento no Cloudflare (Public Hostnames)

Volte ao painel do Cloudflare Tunnel onde você parou. Agora vamos configurar como o Cloudflare fala com seu cluster.

A estratégia mais escalável é criar um **Wildcard** que joga tudo para o Traefik, e o Traefik decide baseado no Ingress.

Na aba **Public Hostnames** do túnel:

- **Subdomain:** `*` (asterisco)
- **Domain:** `seudominio.com.br`
- **Service Type:** HTTP
- **URL:** `traefik.traefik.svc.cluster.local:80` (Este é o endereço interno do serviço do Traefik no Kubernetes).

Salve o túnel.

> **Dica:** ao invés de criar o subdomínio com `*`, coloque qualquer texto para que o Cloudflare possa criar automaticamente um registro do tipo CNAME. Depois, volte e altere o CNAME para `*` e o subdomínio na aba hostname também para `*`.

> **O que fizemos:** Qualquer requisição para `app.seudominio.com.br` ou `painel.seudominio.com.br` baterá no Cloudflare → descerá pelo Túnel → chegará no Traefik. O Traefik lerá o cabeçalho e roteará para o pod correto.

---

## 🔗 Passo 7: Expondo o Portainer via Ingress

Agora precisamos dizer ao Traefik para aceitar tráfego destinado ao Portainer.

Precisamos forçar o Traefik a dizer para o Portainer: "Confie em mim, a conexão original era HTTPS". Faremos isso criando um Middleware no Traefik.

Aplique o arquivo de middleware já existente:

```bash
kubectl apply -f yaml/middleware-https.yaml
```

Edite o arquivo `yaml/portainer-ingress.yaml` usando `nano` ou `vi` substituindo pelo seu domínio e aplique:

```bash
nano yaml/portainer-ingress.yaml
```

```bash
kubectl apply -f yaml/portainer-ingress.yaml
```

Reinicie a instancia para ter certeza que toda a stack ira funcionar.

```bash
sudo reboot
```

---

## 📈 Passo 8: Configuração de Monitoramento (Loki, Prometheus, Grafana)

Para ter visibilidade total sobre o cluster, vamos subir a stack de monitoramento completa pré-configurada na pasta `yaml/monitoring`.

### O que será instalado:
- **Prometheus:** Coleta as métricas.
- **Node Exporter:** Métricas de hardware/OS da instância.
- **Kube State Metrics:** Métricas dos objetos Kubernetes (Pods, Services, etc.).
- **Loki:** Sistema de logs (como um "grep" distribuído).
- **Promtail:** Agente que lê os logs e envia pro Loki.
- **Grafana:** Dashboard visual unificado.

### Executando a Instalação

A ordem é importante. Execute os comandos abaixo na raiz do projeto (onde está a pasta `yaml`):

```bash
# 1. Criar Namespace e Storage
kubectl apply -f yaml/monitoring/namespace-storage.yaml

# 2. Instalar Exporters (Node e Kube State)
kubectl apply -f yaml/monitoring/exporters.yaml

# 3. Instalar Metrics (Prometheus)
kubectl apply -f yaml/monitoring/metrics.yaml

# 4. Instalar Logging (Loki + Promtail)
kubectl apply -f yaml/monitoring/logging.yaml

# 5. Instalar Grafana
kubectl apply -f yaml/monitoring/grafana.yaml
```

### Acessando o Grafana

Após aplicar, o Grafana estará disponível no domínio configurado no arquivo `grafana.yaml`.

- **URL:** `https://grafana.seudominio.com.br` (ajuste no DNS Cloudflare se necessário)
- **Usuário padrão:** `admin`
- **Senha padrão:** `admin` (será solicitado para trocar no primeiro login)

> **Nota:** Certifique-se de criar o CNAME no Cloudflare apontando `grafana` para o seu túnel, assim como fez para o Portainer.

### Dashboards Recomendados

Para começar, importe estes dashboards oficiais que funcionam perfeitamente com esta stack:

1.  **Kubernetes Cluster (ID: 15661):** Visão geral completa (CPU, RAM, Pods).
    - *Ao importar, selecione o datasource "Prometheus".*
2.  **Node Exporter Full (ID: 1860):** Detalhes profundos do Hardware (Disco, Rede, Linux).
3.  **Loki Logs (ID: 15141):** Explorador de logs e busca.
    - *Ao importar, selecione o datasource "Loki".*
    
*Como importar: No Grafana, vá em Dashboards > New > Import e digite o ID.*

### Validação do Monitoramento

Verifique se todos os pods estão rodando no namespace de monitoramento:
```bash
kubectl get pods -n monitoring
```
> **Resultado esperado:** Todos os pods (loki, grafana, prometheus, etc.) com status `Running`.

---

## ✅ Passo 9: Validação Final e Testes

Vamos rodar verificações para garantir que tudo está saudável.

### Verifique os Pods
```bash
kubectl get pods -A
```
> **Resultado esperado:** Todos os pods (cloudflared, traefik, portainer) devem estar com status `Running`.

### Verifique o Log do Cloudflare
```bash
kubectl logs -l app=cloudflared -n kube-system --tail=20
```
> **Resultado esperado:** Logs indicando `Connection ... registered` e `Connected to ...`.

### Teste de Acesso Externo
Abra seu navegador e acesse `https://portainer.seudominio.com.br`.  
O SSL deve ser gerenciado pela Cloudflare (o cadeado deve aparecer). Você deve ver a tela de criação de senha do Portainer.

### Teste de Escalabilidade (Simulação)
Para provar que a infra é escalável, vamos subir um app de teste rápido (Whoami) e expor em outro subdomínio.

```bash
# Cria o deployment
kubectl create deployment whoami --image=traefik/whoami
# Cria o serviço
kubectl expose deployment whoami --port=80
# Cria o Ingress
kubectl create ingress whoami-ingress \
  --class=traefik \
  --rule="whoami.seudominio.com.br/*=whoami:80"
```

Acesse `https://whoami.seudominio.com.br`. Se carregar os dados do container, sua infraestrutura de roteamento dinâmico está perfeita.

---

## 🧪 Passo 10: Teste Real

Agora que o túnel está de pé e enviando dados para o Traefik, vamos testar se o Portainer está respondendo.

### Verifique o DNS (Painel da Cloudflare)
Certifique-se de que você criou o registro CNAME no painel da Cloudflare (DNS) apontando para o túnel.

- **Type:** CNAME
- **Name:** portainer (ou `*` para cobrir tudo)
- **Target:** `[UUID-do-seu-tunnel].cfargotunnel.com`
- **Proxy status:** Proxied (Laranja)

### Acesse no Navegador
Abra `https://portainer.seudominio.com.br`.

> **Resultado esperado:**
> - A conexão deve ser segura (cadeado SSL da Cloudflare).
> - A tela de configuração de senha inicial do Portainer deve aparecer.

Se abrir a tela do Portainer, parabéns! Você tem uma infraestrutura Kubernetes profissional rodando. Posso ajudar a configurar o primeiro deploy ou ajustar algo mais?

---

## 🚨 Passo 11: Possíveis Problemas

Aqui estão soluções para problemas comuns que podem surgir durante a configuração.

### Problema 1: Portainer não aceita criação de usuário

Se o tempo entre a criação do cluster e o acesso for maior que 5 minutos, recrie o cluster. Por motivos de segurança, o Portainer desabilita a criação do usuário admin se você não fizer isso nos primeiros 5 minutos após o container iniciar.

#### Solução: Reiniciar o Pod
Precisamos apenas reiniciar o serviço do Portainer para "zerar o cronômetro".

1. Rode este comando no seu terminal (SSH da Oracle):
   ```bash
   kubectl rollout restart deployment portainer -n portainer
   ```

2. Aguarde uns 15 a 30 segundos para ele subir novamente. Você pode acompanhar com:
   ```bash
   kubectl get pods -n portainer
   ```
   Espere até o status estar `Running` e o `AGE` ser de alguns segundos.

3. Imediatamente vá ao navegador, atualize a página (F5) e crie o usuário.

> **Dica importante:** As versões novas do Portainer exigem uma senha de pelo menos 12 caracteres. Se a senha for curta, ele às vezes nem avisa o erro, só não clica.

Se não resolver, siga para o próximo problema.

> **Dica de ouro:** Tente em uma Janela Anônima primeiro (para ignorar caches antigos de falha).

Crie o usuário. Isso deve resolver definitivamente o problema de origem inválida.

### Problema 2: Logs não aparecem no Loki (Promtail)

Em alguns ambientes (especialmente Oracle Linux/Ubuntu com regras de firewall estritas), o Promtail pode falhar ao tentar conectar na API do Kubernetes para descobrir os pods (Erro `connect: no route to host` ou `dial tcp 10.43.0.1:443`).

#### Solução Temporária (Static Config)
O arquivo `yaml/monitoring/logging.yaml` foi ajustado para usar uma configuração **estática**, lendo diretamente os arquivos de log em `/var/log/pods` sem depender da API do Kubernetes.

> **Limitação:** Com esta configuração, perdemos alguns metadados automáticos (como labels de `app` e `namespace` bonitinhos), mas garantimos que os logs sejam coletados. Futuramente, ao corrigir o roteamento de rede do cluster (CNI/Firewall), podemos reverter para a configuração dinâmica (`kubernetes_sd_configs`).

---



---

## 🎨 Passo Extra: Páginas de Erro Personalizadas

Vamos substituir as páginas de erro padrão "feias" (404 Not Found, 502 Bad Gateway) por uma interface moderna e amigável.

### 1. Instalar o Serviço de Páginas
Aplique o arquivo que criamos, que contém um servidor web leve e o Middleware do Traefik.

```bash
kubectl apply -f yaml/custom-errors.yaml
```

### 2. Como usar nos seus Ingresses
Para ativar as páginas bonitas, adicione a seguinte *annotation* em qualquer arquivo de Ingress (como o `portainer-ingress.yaml` ou `grafana.yaml`):

```yaml
metadata:
  annotations:
    # Adicione esta linha:
    traefik.ingress.kubernetes.io/router.middlewares: traefik-error-pages-middleware@kubernetescrd
```

> **Dica:** O sufixo `@kubernetescrd` diz ao Traefik que estamos referenciando um Middleware definido via Custom Resource (que foi o que criamos no YAML).

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

---

## 📊 Resumo da Arquitetura

Aqui vai um resumo visual do fluxo de tráfego:

1. **Usuário acessa** `portainer.seudominio.com`.
2. **Cloudflare Edge recebe** (SSL Handshake ocorre aqui).
3. **Tráfego viaja seguro** pelo Cloudflare Tunnel até dentro da sua instância OCI.
4. **Pod cloudflared entrega** o pacote para o Service do Traefik.
5. **Traefik verifica o Host** e encaminha para o Pod do Portainer.

> **Benefício de segurança:** Você agora tem uma infraestrutura onde a única porta aberta no firewall da Oracle é a 22 (SSH), tornando o ambiente extremamente seguro contra ataques de negação de serviço direto e varredura de portas.

🎉 **Pronto!** Sua infraestrutura está configurada. Acesse via o domínio Cloudflare e gerencie tudo pelo Portainer.