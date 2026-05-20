# 8. Evidência da Validação (execução real)

Este documento contém a **saída real** do `terraform apply` executado para validar este tutorial — incluindo a configuração de custom domain com Private DNS Zone privada (sem qualquer zona em `azure-api.net`).

## 8.1 Resumo da execução

| Item | Valor |
|------|-------|
| Tenant | `00000000-0000-0000-0000-000000000000` |
| Subscription | `00000000-0000-0000-0000-000000000000` |
| Região | `Brazil South` |
| SKU | `Developer_1` |
| Tempo de provisão do APIM | ~30 min |
| Tempo de configuração de custom domain | **27m56s** (regeneração do cluster TLS) |
| Tempo total | **~60 min** |
| `provisioningState` | `Succeeded` |

## 8.2 Outputs do Terraform

```hcl
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
vnet_name                  = "vnet-internal-dev-brs"
```

> 🔑 **Private VIP = `10.10.1.4`** — usado nos A records da zona `api.internal`.

## 8.3 Recursos provisionados

```text
$ az resource list -g rg-internal-dev-brs --query "[].{name:name}" -o table

Name
-----------------------------------------
api.internal                              ← Private DNS Zone (TLD privado!)
nsg-apim-dev-brs
vnet-internal-dev-brs
log-internal-dev-brs
apim-internal-owner-dev                  ← Nome limpo, sem duplicação
api.internal/link-vnet-api-internal       ← VNet link da Private DNS Zone
appi-internal-dev-brs
Failure Anomalies - appi-internal-dev-brs ← Implícito do App Insights
```

✅ **ZERO** Private DNS Zones em `*.azure-api.net`.

## 8.4 Estado do APIM

```text
$ az apim show -g rg-internal-dev-brs -n apim-internal-owner-dev \
    --query '{name:name,sku:sku.name,vnetType:virtualNetworkType,
              privateIPs:privateIpAddresses,publicIPs:publicIpAddresses,
              provisioningState:provisioningState}'

{
  "name": "apim-internal-owner-dev",
  "privateIPs": ["10.10.1.4"],
  "provisioningState": "Succeeded",
  "publicIPs": ["REDACTED-PUBLIC-IP"],
  "sku": "Developer",
  "vnetType": "Internal"
}
```

✅ `vnetType = Internal`
✅ `provisioningState = Succeeded`
✅ `privateIPs = ["10.10.1.4"]`

## 8.5 Hostnames customizados aplicados

```text
$ az apim show -g rg-internal-dev-brs -n apim-internal-owner-dev \
    --query "hostnameConfigurations[].hostName" -o table

Host
--------------------------------------
apim-internal-owner-dev.azure-api.net   ← Default (alias interno, mantido pelo APIM)
management.api.internal                  ← Custom management
developer.api.internal                   ← Custom developer portal
apim.api.internal                        ← Custom gateway
scm.api.internal                         ← Custom scm/git
```

> ℹ️ O hostname default `*.azure-api.net` permanece como alias interno usado pelo ARM, **mas não é mais o endpoint usado pelos clientes**. Não é necessário (nem recomendado) criar DNS para ele.

## 8.6 Private DNS Zone `api.internal`

```text
$ az network private-dns zone show -g rg-internal-dev-brs -n api.internal

Name          Records
------------  ---------
api.internal  5            (4 A records + 1 SOA implícito)
```

### A records

```text
$ az network private-dns record-set a list -g rg-internal-dev-brs -z api.internal -o table

Name        Ip         Ttl
----------  ---------  -----
apim        10.10.1.4  300
developer   10.10.1.4  300
management  10.10.1.4  300
scm         10.10.1.4  300
```

✅ Todos resolvem para o Private VIP do APIM.

### VNet link

```text
$ az network private-dns link vnet list -g rg-internal-dev-brs -z api.internal -o table

Name                    Reg
----------------------  -----
link-vnet-api-internal  False
```

✅ Link configurado, `registrationEnabled=false` (não queremos auto-registro de VMs).

## 8.7 Log de provisão (resumo cronológico)

```text
tls_private_key.apim:                                  Creation complete after 0s
tls_self_signed_cert.apim:                             Creation complete after 0s
pkcs12_from_pem.apim:                                  Creation complete after 0s
azurerm_resource_group.this:                           Creation complete after 2s
azurerm_log_analytics_workspace.this:                  Creation complete after ~45s
azurerm_virtual_network.this:                          Creation complete after 10s
azurerm_subnet.apim:                                   Creation complete after 8s
azurerm_network_security_group.apim:                   Creation complete after 8s
azurerm_application_insights.this:                     Creation complete after 28s
azurerm_subnet_network_security_group_association:    Creation complete after 5s
azurerm_private_dns_zone.internal:                     Creation complete after ~5s
azurerm_private_dns_zone_virtual_network_link.internal:Creation complete after 35s
azurerm_api_management.this:                           Creation complete after ~30m
azurerm_api_management_logger.appi:                    Creation complete after 5s
azurerm_private_dns_a_record.apim["*"] (4 records):    Creation complete after 2-3s each
azurerm_api_management_custom_domain.this:             Creation complete after 27m56s ⏰

Apply complete! Resources: 19 added, 0 changed, 0 destroyed.
```

## 8.8 Diferenças vs primeira tentativa (lições aprendidas)

| Aspecto | Antes (errado) | Agora (correto) |
|---------|----------------|-----------------|
| Workload | `internalapim` (duplica abreviação `apim`) | `internal` |
| Nome do APIM | `apim-internalapim-owner-dev` | `apim-internal-owner-dev` |
| Estratégia de DNS | 5 Private DNS Zones em `*.azure-api.net` (sub-FQDN) | 1 Private DNS Zone em `api.internal` (TLD privado) |
| Hostnames usados | `*.azure-api.net` defaults | Custom domain `*.api.internal` |
| Certificado TLS | Default Microsoft em `*.azure-api.net` | Self-signed via `tls` + `pkcs12` providers |
| Conflito com outros serviços `*.azure-api.net` | Risco organizacional | **Zero risco** |
| Destroy bloqueado por alerta órfão do App Insights | Sim | Corrigido com `prevent_deletion_if_contains_resources=false` |

## 8.9 Próximos passos para uso real

1. ✅ DNS já resolve dentro da VNet — basta uma VM/peer para testar.
2. Criar APIs no APIM e atribuir Products/Policies.
3. Substituir cert self-signed por cert de **CA confiável** via **Key Vault** (ver [05-configuracao-dns.md §5.4](05-configuracao-dns.md)).
4. (Opcional) Habilitar **Diagnostic Settings** para enviar logs ao Log Analytics.
5. (Opcional) Configurar **VPN/ExpressRoute** para acesso on-prem.

---

⬅️ Anterior: [Cleanup](07-cleanup.md) | 🏠 [Voltar ao README](../README.md)
