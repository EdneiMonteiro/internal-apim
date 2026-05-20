# 1. Pré-requisitos

Antes de provisionar um APIM em modo **Internal**, certifique-se de ter o seguinte preparado.

## 1.1 Conta e permissões

| Item | Detalhe |
|------|---------|
| Subscription Azure | Ativa e com créditos/budget disponível |
| Permissão mínima | `Contributor` no Resource Group destino |
| Permissão de rede | Capacidade de criar VNet, Subnet e NSG |
| Provider registrado | `Microsoft.ApiManagement`, `Microsoft.Network`, `Microsoft.OperationalInsights`, `Microsoft.Insights` |

Para verificar e registrar os providers:

```bash
az provider show -n Microsoft.ApiManagement --query registrationState -o tsv
az provider register --namespace Microsoft.ApiManagement
```

## 1.2 SKU do APIM

> ⚠️ **Importante:** apenas os tiers **Developer** e **Premium** suportam injeção em VNet.

| SKU | VNet | SLA | Custo aprox. | Indicado para |
|-----|------|-----|--------------|---------------|
| Consumption | ❌ | 99.95% | pay-per-call | APIs serverless públicas |
| Developer_1 | ✅ | sem SLA | ~$50/mês | Dev / aprendizado |
| Basic_v2 / Standard_v2 | ❌ Internal | 99.95% | médio | APIs públicas com escala |
| Premium_1+ | ✅ | 99.99% (multi-region) | ~$2.800/mês | Produção empresarial |

Para este tutorial usamos **Developer_1**.

## 1.3 Recursos de rede

### Virtual Network (VNet) + Subnet
- Mesma **região** e **subscription** do APIM.
- A subnet **não pode** ter delegations (deve estar em _None_).
- A subnet **deve ser dedicada** ao APIM (não compartilhe com outros recursos quando possível).
- Espaço CIDR sugerido: **/27 ou maior** (Developer requer ao menos /29, Premium pode escalar mais).

### Network Security Group (NSG)
- **Obrigatório** anexar ao subnet do APIM.
- O Load Balancer interno é seguro por padrão e **rejeita todo inbound** que não esteja explicitamente liberado.
- Regras mínimas exigidas (mais detalhes em [02-arquitetura.md](02-arquitetura.md)).

### Custom domain (recomendado) + Private DNS Zone em TLD privado
- Em modo Internal, configure **custom domain** em um TLD privado (`.internal`) — evita por completo zonas DNS em `azure-api.net`.
- Detalhes em [05-configuracao-dns.md](05-configuracao-dns.md).

### Public IP (opcional)
- Desde **maio/2024** **não é mais necessário** fornecer um Public IP em modo Internal.
- Só forneça um Public IP Standard SKU se quiser controlar o IP público de saída do APIM.

## 1.4 Recursos opcionais recomendados

| Recurso | Por quê |
|---------|---------|
| Log Analytics Workspace | Centralizar logs do APIM e do Application Insights |
| Application Insights | Telemetria detalhada por API (latência, erros, requests) |
| Key Vault | Guardar segredos, **certificados de domínio customizado em produção** |
| Private DNS Zone (em TLD privado, ex: `api.internal`) | Resolução dos hostnames customizados do APIM |

> ⚠️ **NUNCA** crie uma Private DNS Zone para o domínio **apex** `azure-api.net` — isso quebra a resolução de outros serviços Azure que dependem do domínio público. Em vez disso, configure **custom domain** em um TLD privado. Veja detalhes em [05-configuracao-dns.md](05-configuracao-dns.md).

## 1.5 Ferramentas locais (para Terraform)

| Ferramenta | Versão mínima |
|-----------|---------------|
| Terraform | ≥ 1.5 |
| Azure CLI | ≥ 2.50 |
| Git | qualquer recente |

```bash
terraform -version
az version
git --version
```

## 1.6 Tempo de provisão

| Operação | Tempo médio |
|----------|-------------|
| Criar APIM Developer Internal (do zero) | **30–45 minutos** |
| Alterar configuração de VNet | **15+ minutos** |
| Operações de plano de dados (APIs, Products, Policies) | < 1 minuto |

> ⏰ Não é um typo. Provisionar um APIM **realmente leva** 30+ minutos. Esse é o tempo para o backend do Azure criar o stamp dedicado da instância.

---

➡️ Próximo: [Arquitetura](02-arquitetura.md)
