# 4. Tutorial — Terraform

Esta pasta contém um projeto Terraform completo, pronto para provisionar todo o ambiente do tutorial via IaC — incluindo **custom domain** com cert self-signed e **Private DNS Zone** em TLD privado (`api.internal`).

## 4.1 Estrutura

```
terraform/
├── providers.tf            # azurerm + tls + chilicat/pkcs12
├── variables.tf            # inputs (subscription, workload, sku, custom_domain, cert_password, etc)
├── main.tf                 # RG, VNet, Subnet, NSG, APIM, Custom Domain, Private DNS, Log, AppI
├── outputs.tf              # nomes, FQDNs custom, VIP privado
├── terraform.tfvars.example# template de variáveis
└── .gitignore
```

## 4.2 Pré-requisitos

```bash
terraform -version   # ≥ 1.5
az version           # ≥ 2.50
az login
az account set --subscription <SUBSCRIPTION_ID>
```

## 4.3 Providers utilizados

| Provider | Versão | Por quê |
|----------|--------|---------|
| `hashicorp/azurerm` | ~> 4.0 | Recursos Azure |
| `hashicorp/tls` | ~> 4.0 | Geração de chave RSA + cert X.509 self-signed |
| `chilicat/pkcs12` | ~> 0.2 | Conversão PEM → PKCS#12 (formato exigido pelo APIM) |

> 💡 Em produção, prefira certificados de CA confiável armazenados no **Key Vault** — neste caso os providers `tls` e `pkcs12` não são necessários.

## 4.4 Configurar variáveis

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edite `terraform.tfvars`:

```hcl
subscription_id = "<sua-subscription-id>"
tenant_id       = "<seu-tenant-id>"

location       = "brazilsouth"
location_short = "brs"

workload    = "internal"        # NÃO use "internalapim" — duplica a abreviação "apim"
environment = "dev"
owner       = "owner"          # garante unicidade global do APIM

publisher_name  = "Seu Nome"
publisher_email = "seu@email.com"

apim_sku = "Developer_1"

vnet_address_space = ["10.10.0.0/16"]
apim_subnet_prefix = "10.10.1.0/24"

# TLD privado (NUNCA azure-api.net)
custom_domain = "api.internal"

# Senha do PFX (tutorial). Em produção referencie Key Vault.
cert_password = "<your-pfx-password>"
```

## 4.5 Executar

```bash
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Tempo total esperado:
- Provisão do APIM: **~30 minutos**
- Configuração de custom domain: **~10–15 minutos adicionais** (o APIM faz hot-reload da configuração)
- DNS + demais recursos: **~1 minuto cada**

Saída final (parcial):

```
Apply complete! Resources: ~20 added, 0 changed, 0 destroyed.

Outputs:

apim_custom_hostnames = {
  "developer"  = "developer.api.internal"
  "gateway"    = "apim.api.internal"
  "management" = "management.api.internal"
  "scm"        = "scm.api.internal"
}
apim_gateway_custom_url    = "https://apim.api.internal"
apim_name                  = "apim-internal-owner-dev"
apim_private_ip_addresses  = ["10.10.1.4"]
private_dns_zone           = "api.internal"
resource_group_name        = "rg-internal-dev-brs"
```

## 4.6 Recursos provisionados

| # | Recurso | Tipo |
|---|---------|------|
| 1 | `rg-internal-dev-brs` | `Microsoft.Resources/resourceGroups` |
| 2 | `log-internal-dev-brs` | `Microsoft.OperationalInsights/workspaces` |
| 3 | `appi-internal-dev-brs` | `Microsoft.Insights/components` |
| 4 | `vnet-internal-dev-brs` | `Microsoft.Network/virtualNetworks` |
| 5 | `snet-apim-dev` | `Microsoft.Network/virtualNetworks/subnets` |
| 6 | `nsg-apim-dev-brs` | `Microsoft.Network/networkSecurityGroups` |
| 7 | Associação Subnet↔NSG | `Microsoft.Network/.../subnets` |
| 8 | `apim-internal-owner-dev` | `Microsoft.ApiManagement/service` |
| 9 | `appi-logger` | `Microsoft.ApiManagement/service/loggers` |
| 10 | Custom domain do APIM | `Microsoft.ApiManagement/service/hostnameConfigurations` |
| 11 | `api.internal` | `Microsoft.Network/privateDnsZones` |
| 12 | VNet link da Private DNS Zone | `Microsoft.Network/privateDnsZones/virtualNetworkLinks` |
| 13–16 | A records (apim, developer, management, scm) | `Microsoft.Network/privateDnsZones/A` |

## 4.7 Boas práticas adicionais

### Backend remoto
Para times, mova o state para um backend remoto (Azure Storage):

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-prd-brs"
    storage_account_name = "sttfstateprdbrs"
    container_name       = "tfstate"
    key                  = "internal-apim.tfstate"
  }
}
```

### Cert via Key Vault (produção)
Substitua a geração via `tls` provider por referência ao Key Vault:

```hcl
gateway {
  host_name    = local.apim_hostnames.gateway
  key_vault_id = "https://kv-apim-prd-brs.vault.azure.net/secrets/apim-cert"
}
```

### CI/CD
Use OIDC + GitHub Actions com a action [`azure/login`](https://github.com/Azure/login) e workload identity federation — evita armazenar secrets.

### Múltiplos ambientes
Use **workspaces** (`terraform workspace new hml`) ou **diretórios separados** por ambiente.

### Lock e formatação
```bash
terraform fmt -recursive
terraform validate
```

---

⬅️ Anterior: [Tutorial — Portal](03-tutorial-portal.md) | ➡️ Próximo: [Configuração de DNS](05-configuracao-dns.md)
