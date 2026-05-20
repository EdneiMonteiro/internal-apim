# 6. Validação

Após o `terraform apply` (ou criação manual via portal) concluir, vamos validar que o ambiente está saudável.

## 6.1 Conferir os recursos provisionados

```bash
RG=rg-internalapim-dev-brs
az resource list -g $RG --query "[].{name:name, type:type, location:location}" -o table
```

Saída esperada (10 recursos — APIM cria 1 recurso adicional implícito):

```
Name                                Type                                                       Location
----------------------------------  ---------------------------------------------------------  -----------
log-internalapim-dev-brs            Microsoft.OperationalInsights/workspaces                   brazilsouth
appi-internalapim-dev-brs           Microsoft.Insights/components                              brazilsouth
vnet-internalapim-dev-brs           Microsoft.Network/virtualNetworks                          brazilsouth
nsg-apim-dev-brs                    Microsoft.Network/networkSecurityGroups                    brazilsouth
apim-internalapim-owner-dev        Microsoft.ApiManagement/service                            brazilsouth
```

## 6.2 Conferir IP privado e VNet do APIM

```bash
APIM=apim-internalapim-owner-dev
az apim show -g $RG -n $APIM \
  --query '{name:name, sku:sku.name, vnetType:virtualNetworkType, privateIPs:privateIpAddresses, publicIPs:publicIpAddresses}' \
  -o json
```

Saída esperada:

```json
{
  "name": "apim-internalapim-owner-dev",
  "sku": "Developer",
  "vnetType": "Internal",
  "privateIPs": ["10.10.1.4"],
  "publicIPs": ["<ip-de-saida>"]
}
```

## 6.3 Conferir as regras de NSG

```bash
az network nsg rule list -g $RG --nsg-name nsg-apim-dev-brs \
  --query "[].{name:name, dir:direction, prio:priority, action:access, srcTag:sourceAddressPrefix, dstTag:destinationAddressPrefix, port:destinationPortRange}" \
  -o table
```

## 6.4 Testar conectividade ao gateway

### A partir de uma VM na VNet

1. Crie uma **VM Linux pequena** (B1s) em outra subnet da mesma VNet (ou na mesma).
2. SSH para a VM.
3. Edite o `/etc/hosts`:
   ```bash
   echo "10.10.1.4 apim-internalapim-owner-dev.azure-api.net" | sudo tee -a /etc/hosts
   ```
4. Faça uma chamada de health-check (o APIM expõe `/status-0123456789abcdef`):
   ```bash
   curl -k -i https://apim-internalapim-owner-dev.azure-api.net/status-0123456789abcdef
   ```
   Resposta esperada:
   ```
   HTTP/1.1 200 OK
   ```

### Via Bastion (sem expor SSH)

Se preferir não abrir SSH, use **Azure Bastion** para acessar a VM:

```bash
az network bastion ssh \
  --name bas-internalapim-dev-brs \
  --resource-group $RG \
  --target-resource-id <vm-id> \
  --auth-type AAD
```

## 6.5 Verificar telemetria no Application Insights

Após algumas requisições:

1. Portal → `appi-internalapim-dev-brs` → **Live Metrics**.
2. Você deve ver requests em tempo real.
3. **Failures** mostra requisições com erro.
4. **Performance** mostra latência por operação.

## 6.6 Checklist final

- [ ] Resource Group criado com tags corretas
- [ ] APIM com `virtualNetworkType=Internal`
- [ ] APIM com **System Assigned Identity** habilitado
- [ ] Private VIP listado em `privateIpAddresses`
- [ ] NSG associado à subnet do APIM
- [ ] Regras de NSG mínimas presentes
- [ ] Application Insights conectado como Logger no APIM
- [ ] Logs do APIM fluindo para Log Analytics
- [ ] DNS resolve hostnames do APIM para o VIP privado
- [ ] `curl /status-0123456789abcdef` retorna **200 OK** de dentro da VNet

---

⬅️ Anterior: [Configuração de DNS](05-configuracao-dns.md) | ➡️ Próximo: [Cleanup](07-cleanup.md)
