# Internal APIM no Azure — Tutorial passo a passo (PT-BR)

Tutorial completo de como provisionar um **Azure API Management** em modo **Internal VNet** — com explicação dos pré-requisitos, passo-a-passo via Portal e **Infrastructure as Code (Terraform)** pronto para uso.

> 📖 Baseado na documentação oficial: [Deploy your Azure API Management instance to a virtual network — internal mode](https://learn.microsoft.com/en-us/azure/api-management/api-management-using-with-internal-vnet)
>
> 🏷️ Convenção de nomenclatura: [Cloud Adoption Framework — Resource abbreviations](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations)

---

## 🎯 O que você vai aprender

- Diferença entre os modos **External** e **Internal** de VNet integration do APIM.
- Quais recursos do Azure são pré-requisito para um APIM Internal.
- Como configurar **NSG**, **Subnet** e **DNS** para que tudo funcione.
- Como provisionar o ambiente via **Portal Azure** (visual) **ou** **Terraform** (IaC).
- Como validar que o APIM está respondendo no VIP privado.

---

## 🧭 Índice

| # | Documento | Conteúdo |
|---|-----------|----------|
| 1 | [Pré-requisitos](docs/01-pre-requisitos.md) | SKU, permissões, recursos necessários |
| 2 | [Arquitetura](docs/02-arquitetura.md) | Diagrama, decisões e nomenclatura CAF |
| 3 | [Tutorial — Portal Azure](docs/03-tutorial-portal.md) | Passo-a-passo manual via portal |
| 4 | [Tutorial — Terraform](docs/04-tutorial-terraform.md) | Provisão via IaC |
| 5 | [Configuração de DNS](docs/05-configuracao-dns.md) | Resolução dos hostnames internos |
| 6 | [Validação](docs/06-validacao.md) | Como testar o gateway interno |
| 7 | [Cleanup](docs/07-cleanup.md) | Como destruir o ambiente |

---

## ⚡ Quick start (Terraform)

> Requer **Terraform ≥ 1.5**, **Azure CLI** logado e um **publisher e-mail** válido.

```bash
git clone https://github.com/EdneiMonteiro/internal-apim.git
cd internal-apim/terraform

# 1. Configure variáveis
cp terraform.tfvars.example terraform.tfvars
# Edite terraform.tfvars com seu publisher_email, subscription, owner etc.

# 2. Faça login no Azure
az login
az account set --subscription <SUBSCRIPTION_ID>

# 3. Provisione (⚠️ APIM Developer leva ~30-45 minutos)
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Ao final você terá:

| Recurso | Nome (default) | Abreviação CAF |
|---------|----------------|----------------|
| Resource Group | `rg-internalapim-dev-brs` | `rg` |
| Virtual Network | `vnet-internalapim-dev-brs` | `vnet` |
| Subnet | `snet-apim-dev` | `snet` |
| Network Security Group | `nsg-apim-dev-brs` | `nsg` |
| API Management | `apim-internalapim-owner-dev` | `apim` |
| Log Analytics Workspace | `log-internalapim-dev-brs` | `log` |
| Application Insights | `appi-internalapim-dev-brs` | `appi` |

---

## 💰 Custos estimados

| SKU | Suporta VNet | Custo aproximado (US$) |
|-----|--------------|-----------------------|
| Consumption | ❌ | pay-per-call |
| Developer_1 | ✅ (sem SLA) | ~$50/mês |
| Basic_v2 / Standard_v2 | ❌ (Internal) | — |
| Premium_1 | ✅ | ~$2,800/mês |

> 💡 Para tutoriais e ambientes de aprendizado use **Developer_1** — mesma feature set do Premium mas sem SLA e ~50x mais barato.

---

## 🛡️ Licença

Este projeto está licenciado sob os termos da licença incluída em [LICENSE](LICENSE).

---

## ✍️ Autor

**Ednei Monteiro** — [@EdneiMonteiro](https://github.com/EdneiMonteiro)
