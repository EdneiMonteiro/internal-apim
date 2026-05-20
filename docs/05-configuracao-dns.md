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

## 5.4 Implementação via Azure CLI (terminal)

Se você não usa Terraform — ou quer entender o que cada bloco do IaC faz — execute os passos abaixo no shell. Os comandos assumem variáveis exportadas e que você já tem o APIM provisionado.

### 5.4.1 Variáveis base

```bash
export SUBSCRIPTION_ID="<sua-subscription-id>"
export RG="rg-internal-dev-brs"
export LOCATION="brazilsouth"
export VNET="vnet-internal-dev-brs"
export APIM="apim-internal-owner-dev"
export DOMAIN="api.internal"
export CERT_PWD="<your-pfx-password>"

az login
az account set --subscription "$SUBSCRIPTION_ID"
```

Pegue o Private VIP do APIM (necessário para os A records):

```bash
export APIM_VIP=$(az apim show -g "$RG" -n "$APIM" \
  --query "privateIpAddresses[0]" -o tsv)
echo "Private VIP: $APIM_VIP"
```

### 5.4.2 Gerar certificado self-signed (OpenSSL)

```bash
# Cria diretório de trabalho temporário
mkdir -p /tmp/apim-cert && cd /tmp/apim-cert

# 1. Chave privada RSA 2048
openssl genrsa -out apim.key 2048

# 2. CSR config com Subject Alternative Names para os 4 FQDNs
cat > openssl.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions     = v3_req
prompt             = no

[req_distinguished_name]
CN = apim.${DOMAIN}
O  = Internal APIM Tutorial

[v3_req]
keyUsage         = keyEncipherment, digitalSignature
extendedKeyUsage = serverAuth
subjectAltName   = @alt_names

[alt_names]
DNS.1 = apim.${DOMAIN}
DNS.2 = developer.${DOMAIN}
DNS.3 = management.${DOMAIN}
DNS.4 = scm.${DOMAIN}
EOF

# 3. Certificado self-signed (validade 1 ano)
openssl req -new -x509 -days 365 \
  -key apim.key \
  -out apim.crt \
  -config openssl.cnf \
  -extensions v3_req

# 4. Empacota em PKCS#12 (formato exigido pelo APIM)
openssl pkcs12 -export \
  -inkey apim.key \
  -in apim.crt \
  -out apim.pfx \
  -passout pass:"$CERT_PWD"

# 5. Base64 para passar no body da REST API / az apim
export CERT_B64=$(base64 -i apim.pfx | tr -d '\n')
echo "Cert PFX gerado e codificado em base64 (${#CERT_B64} chars)"
```

### 5.4.3 Criar a Private DNS Zone

```bash
az network private-dns zone create \
  --resource-group "$RG" \
  --name "$DOMAIN"
```

### 5.4.4 Vincular a Private DNS Zone à VNet

```bash
VNET_ID=$(az network vnet show -g "$RG" -n "$VNET" --query id -o tsv)

az network private-dns link vnet create \
  --resource-group "$RG" \
  --name "link-vnet-$(echo "$DOMAIN" | tr '.' '-')" \
  --zone-name "$DOMAIN" \
  --virtual-network "$VNET_ID" \
  --registration-enabled false
```

### 5.4.5 Criar os A records → Private VIP

```bash
for host in apim developer management scm; do
  az network private-dns record-set a add-record \
    --resource-group "$RG" \
    --zone-name "$DOMAIN" \
    --record-set-name "$host" \
    --ipv4-address "$APIM_VIP" \
    --ttl 300
done

# Validar
az network private-dns record-set a list \
  --resource-group "$RG" \
  --zone-name "$DOMAIN" \
  --query "[].{name:name, ip:aRecords[0].ipv4Address}" -o table
```

Saída esperada:

```
Name        Ip
----------  ---------
apim        10.10.1.4
developer   10.10.1.4
management  10.10.1.4
scm         10.10.1.4
```

### 5.4.6 Configurar custom domain no APIM

> ⚠️ Esta operação aciona um **rebuild do cluster TLS** do APIM e leva **~20–30 minutos**.

A CLI tem flags específicas para cada endpoint type:

```bash
az apim update \
  --resource-group "$RG" \
  --name "$APIM" \
  --set hostnameConfigurations='[
    {
      "type": "Proxy",
      "hostName": "apim.'"$DOMAIN"'",
      "encodedCertificate": "'"$CERT_B64"'",
      "certificatePassword": "'"$CERT_PWD"'",
      "defaultSslBinding": true,
      "negotiateClientCertificate": false
    },
    {
      "type": "DeveloperPortal",
      "hostName": "developer.'"$DOMAIN"'",
      "encodedCertificate": "'"$CERT_B64"'",
      "certificatePassword": "'"$CERT_PWD"'"
    },
    {
      "type": "Management",
      "hostName": "management.'"$DOMAIN"'",
      "encodedCertificate": "'"$CERT_B64"'",
      "certificatePassword": "'"$CERT_PWD"'"
    },
    {
      "type": "Scm",
      "hostName": "scm.'"$DOMAIN"'",
      "encodedCertificate": "'"$CERT_B64"'",
      "certificatePassword": "'"$CERT_PWD"'"
    }
  ]'
```

> 💡 Em ambientes de produção, use `--key-vault-url` em vez de `encodedCertificate` para referenciar um cert armazenado no Key Vault. O APIM precisa ter Managed Identity com permissão `get` no Key Vault.

### 5.4.7 Validar a configuração final

```bash
# Hostnames aplicados
az apim show -g "$RG" -n "$APIM" \
  --query "hostnameConfigurations[].{type:type, host:hostName}" -o table

# Teste de resolução DNS (a partir de uma VM dentro da VNet)
nslookup "apim.${DOMAIN}"

# Health check do gateway (de dentro da VNet; -k por causa do self-signed)
curl -k -i "https://apim.${DOMAIN}/status-0123456789abcdef"
```

### 5.4.8 Limpeza dos arquivos temporários do cert

```bash
cd ~
rm -rf /tmp/apim-cert
unset CERT_B64 CERT_PWD
```

> 🔐 **Importante**: nunca commite o `.pfx`, a `.key` ou a senha em repositórios. Em produção, mova essa geração para um pipeline isolado e armazene o cert no Key Vault.

## 5.5 Alternativas para produção

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

## 5.6 Hosts file (fallback de teste)

Se você não tem DNS configurado mas precisa testar rapidamente de uma máquina dentro da VNet:

```bash
echo "10.10.1.4 apim.api.internal"        | sudo tee -a /etc/hosts
echo "10.10.1.4 developer.api.internal"   | sudo tee -a /etc/hosts
echo "10.10.1.4 management.api.internal"  | sudo tee -a /etc/hosts
echo "10.10.1.4 scm.api.internal"         | sudo tee -a /etc/hosts
```

## 5.7 ⚠️ Atenção ao cert self-signed

Para clientes confiarem no certificado em chamadas HTTPS:

- **Tutorial**: use `curl -k` (ignora validação) ou importe o cert público (`tls_self_signed_cert.apim.cert_pem`) no truststore local.
- **Produção**: use cert de CA confiável (já confiada pelos clientes).

---

⬅️ Anterior: [Tutorial — Terraform](04-tutorial-terraform.md) | ➡️ Próximo: [Validação](06-validacao.md)
