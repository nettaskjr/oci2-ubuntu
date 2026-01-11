# Error Pages Service (404)

Este diretório contém os manifestos para implantar uma página de erro 404 personalizada "Premium" no cluster Kubernetes (K3s).

## Componentes

1.  **ConfigMap (`01-configmap.yaml`)**: Contém o HTML/CSS da página. O design utiliza Glassmorphism, cores vibrantes (Neon) e animações suaves conforme as diretrizes de "Design Aesthetics".
2.  **Deployment & Service (`02-deployment.yaml`)**: Um container Nginx leve (alpine) que monta o ConfigMap em `/usr/share/nginx/html`. Inclui Resources Limits e Probes de saúde.
3.  **Ingress & Middleware (`03-ingress.yaml`)**: Configuração específica para o Traefik (Ingress Controller padrão do K3s).
    *   **Middleware:** Instrui o Traefik a interceptar erros 404 e servir o conteúdo deste serviço.
    *   **Catch-all Ingress:** Define uma rota global que captura qualquer requisição para hosts não configurados e exibe a página de erro.

## Como fazer Deploy

Como estamos utilizando uma estrutura GitOps simplificada (onde a instância clona o repo), você deve commitar estes arquivos na branch `main` (ou na branch que está usando) e aplicar:

```bash
kubectl apply -f k8s-apps/error-pages/
```

## Validação

Acesse qualquer URL inexistente no seu domínio, por exemplo:
`https://seu-dominio.com.br/pagina-que-nao-existe`

Você deverá ver a página personalizada "Perdido no Espaço?".
