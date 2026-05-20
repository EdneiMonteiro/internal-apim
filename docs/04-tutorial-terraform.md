# 4. Tutorial — Terraform

Esta pasta contém um projeto Terraform completo, pronto para provisionar todo o ambiente do tutorial via IaC.

## 4.1 Estrutura

```
terraform/
├── providers.tf            # azurerm + versões
├── variables.tf            # inputs (subscription, workload, sku, cidrs, etc)
├── main.tf                 # resources: RG, VNet, Subnet, NSG, APIM, Log, AppI
├── outputs.tf              # outputs: nomes, FQDNs, VIP privado
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

## 4.3 Configurar variáveis

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

workload    = "internalapim"
environment = "dev"
owner       = "owner"          # garante unicidade global do APIM

publisher_name  = "Seu Nome"
publisher_email = "seu@email.com"

apim_sku = "Developer_1"

vnet_address_space = ["10.10.0.0/16"]
apim_subnet_prefix = "10.10.1.0/24"

tags = {
  workload    = "internal-apim"
  environment = "dev"
  managedBy   = "terraform"
}
```

## 4.4 Executar

```bash
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Saída esperada após o `apply` (parcial):

```
Plan: 9 to add, 0 to change, 0 to destroy.

azurerm_resource_group.this: Creating...
azurerm_resource_group.this: Creation complete after 2s
azurerm_log_analytics_workspace.this: Creating...
azurerm_virtual_network.this: Creating...
azurerm_log_analytics_workspace.this: Creation complete after 47s
azurerm_application_insights.this: Creating...
azurerm_virtual_network.this: Creation complete after 10s
azurerm_subnet.apim: Creating...
azurerm_network_security_group.apim: Creating...
...
azurerm_api_management.this: Still creating... [30m0s elapsed]
azurerm_api_management.this: Creation complete after 32m17s
azurerm_api_management_logger.appi: Creating...
azurerm_api_management_logger.appi: Creation complete after 3s

Apply complete! Resources: 9 added, 0 changed, 0 destroyed.

Outputs:

apim_default_hostnames = {
  "developer" = "apim-internalapim-owner-dev.developer.azure-api.net"
  "gateway" = "apim-internalapim-owner-dev.azure-api.net"
  "management" = "apim-internalapim-owner-dev.management.azure-api.net"
  "portal" = "apim-internalapim-owner-dev.portal.azure-api.net"
  "scm" = "apim-internalapim-owner-dev.scm.azure-api.net"
}
apim_gateway_url = "https://apim-internalapim-owner-dev.azure-api.net"
apim_name = "apim-internalapim-owner-dev"
apim_private_ip_addresses = ["10.10.1.4"]
resource_group_name = "rg-internalapim-dev-brs"
```

## 4.5 Recursos provisionados

| # | Recurso | Tipo |
|---|---------|------|
| 1 | `rg-internalapim-dev-brs` | `Microsoft.Resources/resourceGroups` |
| 2 | `log-internalapim-dev-brs` | `Microsoft.OperationalInsights/workspaces` |
| 3 | `appi-internalapim-dev-brs` | `Microsoft.Insights/components` |
| 4 | `vnet-internalapim-dev-brs` | `Microsoft.Network/virtualNetworks` |
| 5 | `snet-apim-dev` | `Microsoft.Network/virtualNetworks/subnets` |
| 6 | `nsg-apim-dev-brs` | `Microsoft.Network/networkSecurityGroups` |
| 7 | Associação Subnet↔NSG | `Microsoft.Network/.../subnets` |
| 8 | `apim-internalapim-<owner>-dev` | `Microsoft.ApiManagement/service` |
| 9 | `appi-logger` | `Microsoft.ApiManagement/service/loggers` |

## 4.6 Boas práticas adicionais

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
