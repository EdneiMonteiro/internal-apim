# Internal APIM no Azure

[![ORCID](https://img.shields.io/badge/ORCID-0009--0006--0765--4201-A6CE39?logo=orcid&logoColor=white)](https://orcid.org/0009-0006-0765-4201)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Azure](https://img.shields.io/badge/Cloud-Azure-0078D4?logo=microsoftazure&logoColor=white)](#)
[![Last commit](https://img.shields.io/github/last-commit/EdneiMonteiro/internal-apim)](https://github.com/EdneiMonteiro/internal-apim/commits)

Tutorial completo de como provisionar um **Azure API Management** em modo **Internal VNet** — com explicação dos pré-requisitos, passo-a-passo via Portal e **Infrastructure as Code (Terraform)** pronto para uso.

> ⚠️ Este repositório é um **tutorial / prova de conceito**. Antes de usar em produção, revise: segurança, escalabilidade, observabilidade, custos e conformidade. Veja [DISCLAIMER.md](./DISCLAIMER.md) e [SUPPORT.md](./SUPPORT.md).

> 📖 Baseado na documentação oficial: [Deploy your Azure API Management instance to a virtual network — internal mode](https://learn.microsoft.com/en-us/azure/api-management/api-management-using-with-internal-vnet)
>
> 🏷️ Convenção de nomenclatura: [Cloud Adoption Framework — Resource abbreviations](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations)

---

## 🎯 O que você vai aprender

- Diferença entre os modos **External** e **Internal** de VNet integration do APIM.
- Quais recursos do Azure são pré-requisito para um APIM Internal.
- Como configurar **NSG**, **Subnet** e **DNS** para que tudo funcione.
- **Por que NÃO criar Private DNS Zone em `azure-api.net`** (mesmo em sub-FQDN) e como usar **custom domain** em um TLD privado.
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
| 5 | [Configuração de DNS](docs/05-configuracao-dns.md) | **Custom domain + Private DNS em `.internal`** (não toca `azure-api.net`) |
| 6 | [Validação](docs/06-validacao.md) | Como testar o gateway interno |
| 7 | [Cleanup](docs/07-cleanup.md) | Como destruir o ambiente |
| 8 | [Evidência da validação](docs/08-evidencia-validacao.md) | Saída real do `terraform apply` (validado em Brazil South) |

---

## ⚡ Quick start (Terraform)

> Requer **Terraform ≥ 1.5**, **Azure CLI** logado e um **publisher e-mail** válido.

```bash
git clone https://github.com/EdneiMonteiro/internal-apim.git
cd internal-apim/terraform

# 1. Configure variáveis
cp terraform.tfvars.example terraform.tfvars
# Edite terraform.tfvars com publisher_email, subscription, owner, cert_password etc.

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
| Resource Group | `rg-internal-dev-brs` | `rg` |
| Virtual Network | `vnet-internal-dev-brs` | `vnet` |
| Subnet | `snet-apim-dev` | `snet` |
| Network Security Group | `nsg-apim-dev-brs` | `nsg` |
| API Management | `apim-internal-owner-dev` | `apim` |
| Log Analytics Workspace | `log-internal-dev-brs` | `log` |
| Application Insights | `appi-internal-dev-brs` | `appi` |
| Private DNS Zone | `api.internal` | — |

E o APIM acessível via `https://apim.api.internal` (somente de dentro da VNet).

---

## ✅ Status da validação

> Este tutorial foi **validado com uma execução real** em `Brazil South` usando a SKU `Developer_1`. Veja a saída completa em [docs/08-evidencia-validacao.md](docs/08-evidencia-validacao.md).
>
> - `provisioningState = Succeeded`
> - `vnetType = Internal`
> - Custom domain configurado em `api.internal` (sem zonas em `azure-api.net`)
> - Cert self-signed gerado pelo Terraform via provider `tls` + `chilicat/pkcs12`

---

## 🛡️ Licença

Este projeto está licenciado sob os termos da licença incluída em [LICENSE](LICENSE).

---

## Suporte e Aviso Legal

- Sem SLA nem suporte oficial. Veja [SUPPORT.md](./SUPPORT.md).
- Uso sujeito a [DISCLAIMER.md](./DISCLAIMER.md).
- **Não afiliado nem endossado pela Microsoft.** Marcas usadas apenas para descrição.

## 🤝 Contributing

Issue and pull request creation is restricted to collaborators. See
[CONTRIBUTING.md](CONTRIBUTING.md) for details.
