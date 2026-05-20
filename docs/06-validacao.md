# 6. Validação

Após o `terraform apply` (ou criação manual via portal) concluir, vamos validar que o ambiente está saudável.

## 6.1 Conferir os recursos provisionados

```bash
RG=rg-internal-dev-brs
az resource list -g $RG --query "[].{name:name, type:type, location:location}" -o table
```

Saída esperada (recursos principais):

```
Name                              Type
--------------------------------  ----------------------------------------------------------
log-internal-dev-brs              Microsoft.OperationalInsights/workspaces
appi-internal-dev-brs             Microsoft.Insights/components
vnet-internal-dev-brs             Microsoft.Network/virtualNetworks
nsg-apim-dev-brs                  Microsoft.Network/networkSecurityGroups
apim-internal-owner-dev          Microsoft.ApiManagement/service
api.internal                      Microsoft.Network/privateDnsZones
```

## 6.2 Conferir IP privado e VNet do APIM

```bash
APIM=apim-internal-owner-dev
az apim show -g $RG -n $APIM \
  --query '{name:name, sku:sku.name, vnetType:virtualNetworkType, privateIPs:privateIpAddresses, publicIPs:publicIpAddresses}' \
  -o json
```

Saída esperada:

```json
{
  "name": "apim-internal-owner-dev",
  "sku": "Developer",
  "vnetType": "Internal",
  "privateIPs": ["10.10.1.4"],
  "publicIPs": ["<ip-de-saida>"]
}
```

## 6.3 Conferir hostnames customizados

```bash
az apim show -g $RG -n $APIM \
  --query "hostnameConfigurations[].{type:type, host:hostName, certThumbprint:certificate.thumbprint}" \
  -o table
```

Saída esperada:

```
Type             Host
---------------  --------------------------
Proxy            apim.api.internal
DeveloperPortal  developer.api.internal
Management       management.api.internal
Scm              scm.api.internal
```

## 6.4 Conferir Private DNS Zone

```bash
az network private-dns zone show -g $RG -n api.internal -o table
az network private-dns record-set list -g $RG -z api.internal -o table
```

A record set list deve mostrar 4 A records (`apim`, `developer`, `management`, `scm`) todos apontando para o Private VIP.

## 6.5 Conferir VNet link

```bash
az network private-dns link vnet list -g $RG -z api.internal -o table
```

Deve listar o link para `vnet-internal-dev-brs` com `registration_enabled=false`.

## 6.6 Conferir as regras de NSG

```bash
az network nsg rule list -g $RG --nsg-name nsg-apim-dev-brs \
  --query "[].{name:name, dir:direction, prio:priority, action:access, src:sourceAddressPrefix, dst:destinationAddressPrefix, port:destinationPortRange}" \
  -o table
```

## 6.7 Testar conectividade ao gateway

### A partir de uma VM na VNet

1. Crie uma **VM Linux pequena** (B1s) em outra subnet da mesma VNet.
2. SSH para a VM (via Bastion preferencialmente).
3. Faça uma chamada de health-check (o APIM expõe `/status-0123456789abcdef` no gateway):

   ```bash
   # -k necessário porque o cert é self-signed
   curl -k -i https://apim.api.internal/status-0123456789abcdef
   ```

   Resposta esperada:
   ```
   HTTP/1.1 200 OK
   ```

   Validar a resolução DNS:
   ```bash
   nslookup apim.api.internal
   # → 10.10.1.4
   ```

### Sem VM (hosts file local + VPN/peering)

Se sua máquina está em uma VNet peered/conectada via VPN, basta:

```bash
echo "10.10.1.4 apim.api.internal" | sudo tee -a /etc/hosts
curl -k -i https://apim.api.internal/status-0123456789abcdef
```

## 6.8 Verificar telemetria no Application Insights

Após algumas requisições:

1. Portal → `appi-internal-dev-brs` → **Live Metrics**.
2. Você deve ver requests em tempo real.
3. **Failures** mostra requisições com erro.
4. **Performance** mostra latência por operação.

## 6.9 Checklist final

- [ ] Resource Group criado com tags corretas
- [ ] APIM com `virtualNetworkType=Internal`
- [ ] APIM com **System Assigned Identity** habilitado
- [ ] Private VIP listado em `privateIpAddresses`
- [ ] Hostnames customizados aplicados (gateway, developer_portal, management, scm)
- [ ] NSG associado à subnet do APIM com 7 regras mínimas
- [ ] Application Insights conectado como Logger no APIM
- [ ] Logs do APIM fluindo para Log Analytics
- [ ] Private DNS Zone `api.internal` criada com 4 A records → Private VIP
- [ ] VNet link na Private DNS Zone para `vnet-internal-dev-brs`
- [ ] **NENHUMA** zona Private DNS em `*.azure-api.net`
- [ ] `curl -k /status-0123456789abcdef` em `https://apim.api.internal` retorna **200 OK** de dentro da VNet

---

⬅️ Anterior: [Configuração de DNS](05-configuracao-dns.md) | ➡️ Próximo: [Cleanup](07-cleanup.md)
