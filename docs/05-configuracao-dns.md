# 5. Configuração de DNS

> Esta é a parte que **mais quebra** em deployments de APIM Internal. Leia com atenção.

## 5.1 Por que DNS é crítico

Quando o APIM está em modo Internal:

- Os endpoints (`*.azure-api.net`) **não são registrados no DNS público**.
- O APIM **só responde** a requisições endereçadas aos seus hostnames configurados — **não** ao IP privado diretamente.
- Cabe a **você** garantir que clientes (dentro da VNet, em redes peered, on-prem via VPN/ER) consigam **resolver** os hostnames para o **Private VIP**.

## 5.2 Hostnames default

Para um APIM chamado `apim-internalapim-owner-dev`:

| Endpoint | Hostname |
|----------|----------|
| Gateway | `apim-internalapim-owner-dev.azure-api.net` |
| Developer portal (clássico) | `apim-internalapim-owner-dev.portal.azure-api.net` |
| Developer portal (novo) | `apim-internalapim-owner-dev.developer.azure-api.net` |
| Management endpoint | `apim-internalapim-owner-dev.management.azure-api.net` |
| Git (configuração) | `apim-internalapim-owner-dev.scm.azure-api.net` |

Todos resolvem para o **mesmo Private VIP** (ex: `10.10.1.4`).

## 5.3 ⚠️ NÃO faça isso

**NUNCA** crie uma Private DNS Zone para `azure-api.net` (apex):

```diff
- ❌ Private DNS Zone: azure-api.net          (NUNCA)
+ ✅ Private DNS Zone: apim-internalapim-owner-dev.azure-api.net   (OK)
```

Por que? `azure-api.net` é um domínio público compartilhado por **vários serviços** Microsoft/Azure. Criar uma zone privada para o apex faz com que a sua VNet **deixe de resolver** quaisquer outros `*.azure-api.net` públicos, quebrando dependências silenciosamente.

## 5.4 Abordagens recomendadas

### Opção A — Private DNS Zone restrita a sub-FQDN

Crie uma Private DNS Zone para **apenas o FQDN do seu APIM**:

```bash
RG=rg-internalapim-dev-brs
APIM=apim-internalapim-owner-dev
ZONE="${APIM}.azure-api.net"
VIP="10.10.1.4"
VNET_ID=$(az network vnet show -g $RG -n vnet-internalapim-dev-brs --query id -o tsv)

# Cria a zone restrita ao FQDN do APIM
az network private-dns zone create -g $RG -n $ZONE

# Linka a VNet à zone
az network private-dns link vnet create \
  -g $RG -n link-vnet-${APIM} \
  --zone-name $ZONE \
  --virtual-network $VNET_ID \
  --registration-enabled false

# Cria A records para cada endpoint (todos apontando para o mesmo VIP)
for host in "@" "portal" "developer" "management" "scm"; do
  az network private-dns record-set a add-record \
    -g $RG -z $ZONE -n $host -a $VIP
done
```

### Opção B — DNS corporativo (Active Directory / BIND)

Na sua zona DNS corporativa (`corp.contoso.com`, ou diretamente em `azure-api.net` quando você não controla nada Azure que use o domínio), crie **A records explícitos**:

```
apim-internalapim-owner-dev.azure-api.net.              A   10.10.1.4
apim-internalapim-owner-dev.portal.azure-api.net.       A   10.10.1.4
apim-internalapim-owner-dev.developer.azure-api.net.    A   10.10.1.4
apim-internalapim-owner-dev.management.azure-api.net.   A   10.10.1.4
apim-internalapim-owner-dev.scm.azure-api.net.          A   10.10.1.4
```

### Opção C — Custom domain

Para evitar lidar com `azure-api.net`, configure um **custom domain**:

1. No APIM → **Custom domains** → adicione, por exemplo, `api.contoso.com`.
2. Anexe certificado (de PEM/PFX ou referenciado via Key Vault).
3. No DNS corporativo, crie `api.contoso.com A 10.10.1.4`.

> 💡 Custom domain elimina o problema do apex `azure-api.net`. Recomendado para produção.

## 5.5 Testar resolução

De uma **VM dentro da VNet** (ou peered):

```bash
nslookup apim-internalapim-owner-dev.azure-api.net
# deve retornar 10.10.1.4 (ou o VIP que você configurou)
```

Sem VM, use uma alteração temporária no `/etc/hosts`:

```bash
echo "10.10.1.4 apim-internalapim-owner-dev.azure-api.net"             | sudo tee -a /etc/hosts
echo "10.10.1.4 apim-internalapim-owner-dev.portal.azure-api.net"      | sudo tee -a /etc/hosts
echo "10.10.1.4 apim-internalapim-owner-dev.developer.azure-api.net"   | sudo tee -a /etc/hosts
echo "10.10.1.4 apim-internalapim-owner-dev.management.azure-api.net"  | sudo tee -a /etc/hosts
```

> ⚠️ `/etc/hosts` só funciona se a máquina tiver **rota IP** até o Private VIP (mesma VNet, peered, VPN ou ExpressRoute).

---

⬅️ Anterior: [Tutorial — Terraform](04-tutorial-terraform.md) | ➡️ Próximo: [Validação](06-validacao.md)
