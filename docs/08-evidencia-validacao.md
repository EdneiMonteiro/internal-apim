# 8. Evidência da Validação (execução real)

Este documento contém a **saída real** do `terraform apply` executado para validar este tutorial.

## 8.1 Resumo da execução

| Item | Valor |
|------|-------|
| Tenant | `00000000-0000-0000-0000-000000000000` |
| Subscription | `00000000-0000-0000-0000-000000000000` |
| Região | `Brazil South` |
| SKU | `Developer_1` |
| Tempo total de provisão | **29min51s** (APIM) + ~1min (demais recursos) |
| `provisioningState` | `Succeeded` |

## 8.2 Outputs do Terraform

```hcl
apim_default_hostnames = {
  "developer"  = "apim-internalapim-owner-dev.developer.azure-api.net"
  "gateway"    = "apim-internalapim-owner-dev.azure-api.net"
  "management" = "apim-internalapim-owner-dev.management.azure-api.net"
  "portal"     = "apim-internalapim-owner-dev.portal.azure-api.net"
  "scm"        = "apim-internalapim-owner-dev.scm.azure-api.net"
}
apim_gateway_url           = "https://apim-internalapim-owner-dev.azure-api.net"
apim_name                  = "apim-internalapim-owner-dev"
apim_private_ip_addresses  = ["10.10.1.4"]
apim_subnet_id             = "/subscriptions/.../subnets/snet-apim-dev"
application_insights_id    = "/subscriptions/.../components/appi-internalapim-dev-brs"
log_analytics_workspace_id = "/subscriptions/.../workspaces/log-internalapim-dev-brs"
resource_group_name        = "rg-internalapim-dev-brs"
vnet_name                  = "vnet-internalapim-dev-brs"
```

> 🔑 **Private VIP = `10.10.1.4`** — esse é o IP que você usa nos registros DNS.

## 8.3 Recursos provisionados (az CLI)

```text
$ az resource list -g rg-internalapim-dev-brs -o table

Name                                           Location
---------------------------------------------  -----------
vnet-internalapim-dev-brs                      brazilsouth
nsg-apim-dev-brs                               brazilsouth
log-internalapim-dev-brs                       brazilsouth
apim-internalapim-owner-dev                   brazilsouth
appi-internalapim-dev-brs                      brazilsouth
Failure Anomalies - appi-internalapim-dev-brs  global
```

> ℹ️ "Failure Anomalies" é uma alerta criada automaticamente pelo Application Insights.

## 8.4 Estado do APIM

```text
$ az apim show -g rg-internalapim-dev-brs -n apim-internalapim-owner-dev \
    --query '{name:name,sku:sku.name,vnetType:virtualNetworkType,location:location,
              privateIPs:privateIpAddresses,publicIPs:publicIpAddresses,
              gatewayUrl:gatewayUrl,provisioningState:provisioningState}'

{
  "gatewayUrl": "https://apim-internalapim-owner-dev.azure-api.net",
  "location": "Brazil South",
  "name": "apim-internalapim-owner-dev",
  "privateIPs": ["10.10.1.4"],
  "provisioningState": "Succeeded",
  "publicIPs": ["4.228.8.183"],
  "sku": "Developer",
  "vnetType": "Internal"
}
```

✅ `vnetType = Internal` — modo correto
✅ `provisioningState = Succeeded` — provisão concluída
✅ `privateIPs = ["10.10.1.4"]` — VIP interno disponível
✅ `publicIPs = ["4.228.8.183"]` — apenas para tráfego de saída (Azure-managed; em modo Internal o gateway **não escuta** neste IP)

## 8.5 NSG rules aplicadas

```text
$ az network nsg rule list -g rg-internalapim-dev-brs --nsg-name nsg-apim-dev-brs -o table

Name                                 Dir       Prio   Action  Src                Dst             Port
-----------------------------------  --------  -----  ------  -----------------  --------------  ------
Inbound-ApiManagement-Mgmt-3443      Inbound   100    Allow   ApiManagement      VirtualNetwork  3443
Inbound-AzureLoadBalancer-6390       Inbound   110    Allow   AzureLoadBalancer  VirtualNetwork  6390
Outbound-Storage-443                 Outbound  100    Allow   VirtualNetwork     Storage         443
Outbound-SQL-1433                    Outbound  110    Allow   VirtualNetwork     SQL             1433
Outbound-KeyVault-443                Outbound  120    Allow   VirtualNetwork     AzureKeyVault   443
Outbound-AzureMonitor                Outbound  130    Allow   VirtualNetwork     AzureMonitor    443,1886
Outbound-Internet-80-CertValidation  Outbound  140    Allow   VirtualNetwork     Internet        80
```

Todas as 7 regras mínimas para modo Internal foram aplicadas ✅

## 8.6 Log de provisão (resumo)

```text
azurerm_resource_group.this:           Creation complete after 2s
azurerm_log_analytics_workspace.this:  Creation complete after 47s
azurerm_virtual_network.this:          Creation complete after 10s
azurerm_subnet.apim:                   Creation complete after 8s
azurerm_network_security_group.apim:   Creation complete after 8s
azurerm_application_insights.this:     Creation complete after 25s
azurerm_subnet_network_security_group_association.apim: Creation complete after 5s
azurerm_api_management.this:           Creation complete after 29m51s   ⏰
azurerm_api_management_logger.appi:    Creation complete after 5s

Apply complete! Resources: 9 added, 0 changed, 0 destroyed.
```

## 8.7 Próximos passos para uso real

1. Configurar **DNS** (Private DNS Zone ou DNS corporativo) — veja [05-configuracao-dns.md](05-configuracao-dns.md).
2. Subir uma **VM** dentro da VNet (ou peered) para testar conectividade.
3. Criar APIs no APIM e atribuir Products/Policies.
4. (Opcional) Configurar **custom domain** para evitar `azure-api.net`.
5. (Opcional) Habilitar **Diagnostic Settings** para enviar logs ao Log Analytics.

---

⬅️ Anterior: [Cleanup](07-cleanup.md) | 🏠 [Voltar ao README](../README.md)
