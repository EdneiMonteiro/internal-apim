# 5. Configuração de DNS — abordagem custom domain

> Esta é a parte que **mais quebra** em deployments de APIM Internal. Leia com atenção.

## 5.1 Por que **NÃO** usar Private DNS Zone em `azure-api.net`

Quando o APIM está em modo Internal, é tentador resolver os hostnames default (`<apim-name>.azure-api.net`) através de uma Private DNS Zone na VNet. **Não faça isso**.

`azure-api.net` é um domínio público da Microsoft compartilhado por **vários serviços**. Conforme a [documentação oficial](https://learn.microsoft.com/azure/api-management/api-management-using-with-internal-vnet#dns-configuration-for-internal-virtual-network-scenarios):

> Creating a Private DNS zone or authoritative forward lookup zone for the apex domain (`azure-api.net`) is not supported and can introduce unintended resolution failures.
>
> If a Private DNS zone is created for `azure-api.net`:
> - The zone becomes authoritative within the customer DNS scope
> - Public records published by Azure are no longer resolvable
> - Other Azure services that rely on `*.azure-api.net` may fail name resolution
> - Customers must implement complex DNS forwarding to public resolvers to avoid breakage

Mesmo zonas sub-FQDN (`<apim>.azure-api.net`) carregam risco operacional — políticas corporativas e zonas privadas com escopo amplo podem terminar quebrando resolução de outros serviços do mesmo provedor de plano de dados.

✅ **A abordagem recomendada — e que este tutorial implementa — é configurar um custom domain em um TLD privado**, totalmente isolado de `azure-api.net`.

## 5.2 Visão geral da solução

```
┌──────────────────────────────────────────────────────────────┐
│  Cliente HTTP em VNet/peered/on-prem                         │
│                                                              │
│  curl https://apim.api.internal/<api>/...                    │
└─────────────────────────┬────────────────────────────────────┘
                          │ resolve apim.api.internal
                          ▼
┌──────────────────────────────────────────────────────────────┐
│  Azure Private DNS Zone:  api.internal                       │
│    A apim         → 10.10.1.4                                │
│    A developer    → 10.10.1.4                                │
│    A management   → 10.10.1.4                                │
│    A scm          → 10.10.1.4                                │
└─────────────────────────┬────────────────────────────────────┘
                          │ retorna 10.10.1.4 (Private VIP)
                          ▼
┌──────────────────────────────────────────────────────────────┐
│  APIM Internal — custom hostnames                            │
│    gateway          → apim.api.internal                      │
│    developer_portal → developer.api.internal                 │
│    management       → management.api.internal                │
│    scm              → scm.api.internal                       │
│                                                              │
│  Cert TLS: self-signed (tutorial) com SANs para os 4 FQDNs   │
│            (em prod use cert emitido por CA + Key Vault)     │
└──────────────────────────────────────────────────────────────┘
```

> 🔒 **Sobre o TLD `.internal`**: é reservado pela [ICANN](https://www.icann.org/en/board-activities-and-meetings/materials/approved-resolutions-regular-meeting-of-the-icann-board-24-07-2024-en#section1.b) para uso privado (não roteável publicamente). Outras opções: `.home.arpa` (RFC 8375), um subdomínio organizacional sob seu controle (ex: `int.contoso.com`), ou o TLD legado `.local` (não recomendado por conflito com mDNS).

## 5.3 Implementação via Terraform

O `terraform/main.tf` deste repo já implementa toda essa configuração. As 4 partes principais:

### 5.3.1 Certificado self-signed (TLS provider)

```hcl
resource "tls_private_key" "apim" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "apim" {
  private_key_pem = tls_private_key.apim.private_key_pem

  subject {
    common_name  = "apim.api.internal"
    organization = "Internal APIM Tutorial"
  }

  validity_period_hours = 8760  # 1 ano

  allowed_uses = ["key_encipherment", "digital_signature", "server_auth"]

  dns_names = [
    "apim.api.internal",
    "developer.api.internal",
    "management.api.internal",
    "scm.api.internal",
  ]
}

resource "pkcs12_from_pem" "apim" {
  password        = var.cert_password
  cert_pem        = tls_self_signed_cert.apim.cert_pem
  private_key_pem = tls_private_key.apim.private_key_pem
}
```

### 5.3.2 Custom domain no APIM

```hcl
resource "azurerm_api_management_custom_domain" "this" {
  api_management_id = azurerm_api_management.this.id

  gateway {
    host_name            = "apim.api.internal"
    certificate          = pkcs12_from_pem.apim.result
    certificate_password = var.cert_password
    default_ssl_binding  = true
  }

  developer_portal { host_name = "developer.api.internal"   ; certificate = pkcs12_from_pem.apim.result ; certificate_password = var.cert_password }
  management       { host_name = "management.api.internal"  ; certificate = pkcs12_from_pem.apim.result ; certificate_password = var.cert_password }
  scm              { host_name = "scm.api.internal"         ; certificate = pkcs12_from_pem.apim.result ; certificate_password = var.cert_password }
}
```

### 5.3.3 Private DNS Zone em `api.internal`

```hcl
resource "azurerm_private_dns_zone" "internal" {
  name                = "api.internal"
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "internal" {
  name                  = "link-vnet-api-internal"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.internal.name
  virtual_network_id    = azurerm_virtual_network.this.id
  registration_enabled  = false
}
```

### 5.3.4 A records → Private VIP

```hcl
resource "azurerm_private_dns_a_record" "apim" {
  for_each            = toset(["apim", "developer", "management", "scm"])
  name                = each.value
  zone_name           = azurerm_private_dns_zone.internal.name
  resource_group_name = azurerm_resource_group.this.name
  ttl                 = 300
  records             = azurerm_api_management.this.private_ip_addresses
}
```

## 5.4 Alternativas para produção

| Item | Tutorial | Produção |
|------|----------|----------|
| Certificado | self-signed via TLS provider | CA confiável (DigiCert, Let's Encrypt, AD CS interna) referenciada no APIM via `key_vault_id` |
| Senha do PFX | hardcoded em `terraform.tfvars` | Azure Key Vault Secret + variable indireta |
| TLD privado | `api.internal` | subdomínio sob seu controle (ex: `apim.corp.<empresa>.com`) |
| DNS | Azure Private DNS Zone | Azure Private DNS Zone **ou** DNS corporativo (BIND/AD) com forwarding |

### Referência via Key Vault (recomendado para produção)

```hcl
resource "azurerm_api_management_custom_domain" "this" {
  api_management_id = azurerm_api_management.this.id

  gateway {
    host_name    = "api.contoso.com"
    key_vault_id = "https://kv-apim-prd-brs.vault.azure.net/secrets/apim-cert"
  }
}
```

O APIM precisa ter **Managed Identity** com permissão `get` no Key Vault.

## 5.5 Hosts file (fallback de teste)

Se você não tem DNS configurado mas precisa testar rapidamente de uma máquina dentro da VNet:

```bash
echo "10.10.1.4 apim.api.internal"        | sudo tee -a /etc/hosts
echo "10.10.1.4 developer.api.internal"   | sudo tee -a /etc/hosts
echo "10.10.1.4 management.api.internal"  | sudo tee -a /etc/hosts
echo "10.10.1.4 scm.api.internal"         | sudo tee -a /etc/hosts
```

## 5.6 ⚠️ Atenção ao cert self-signed

Para clientes confiarem no certificado em chamadas HTTPS:

- **Tutorial**: use `curl -k` (ignora validação) ou importe o cert público (`tls_self_signed_cert.apim.cert_pem`) no truststore local.
- **Produção**: use cert de CA confiável (já confiada pelos clientes).

---

⬅️ Anterior: [Tutorial — Terraform](04-tutorial-terraform.md) | ➡️ Próximo: [Validação](06-validacao.md)
