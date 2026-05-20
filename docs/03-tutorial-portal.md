# 3. Tutorial — Portal Azure

Este passo-a-passo cria o ambiente **manualmente** via [portal.azure.com](https://portal.azure.com). Use-o para entender o que acontece "por baixo dos panos" antes de partir para o Terraform.

> 💡 Se preferir IaC, pule direto para [04-tutorial-terraform.md](04-tutorial-terraform.md).

> ℹ️ **Sobre custom domain**: este capítulo cria o APIM com os hostnames default (`*.azure-api.net`). A configuração do **custom domain** em TLD privado (recomendada) é coberta em [05-configuracao-dns.md](05-configuracao-dns.md) — execute-a logo após este capítulo.

## 3.1 Criar o Resource Group

1. No portal, clique em **Create a resource** → **Resource group**.
2. Preencha:
   - **Subscription**: a sua.
   - **Resource group**: `rg-internal-dev-brs`
   - **Region**: `(South America) Brazil South`
3. Adicione as tags:
   - `workload=internal-apim`
   - `environment=dev`
   - `managedBy=portal`
4. **Review + create** → **Create**.

## 3.2 Criar o Log Analytics Workspace

1. Procure por **Log Analytics workspaces** → **Create**.
2. Preencha:
   - **Resource group**: `rg-internal-dev-brs`
   - **Name**: `log-internal-dev-brs`
   - **Region**: `Brazil South`
3. **Pricing tier**: `Pay-as-you-go (Per GB 2018)`.
4. **Review + create** → **Create**.

## 3.3 Criar o Application Insights

1. Procure por **Application Insights** → **Create**.
2. Preencha:
   - **Resource group**: `rg-internal-dev-brs`
   - **Name**: `appi-internal-dev-brs`
   - **Region**: `Brazil South`
   - **Resource Mode**: `Workspace-based`
   - **Log Analytics Workspace**: `log-internal-dev-brs`
3. **Review + create** → **Create**.

## 3.4 Criar a Virtual Network

1. Procure por **Virtual networks** → **Create**.
2. Aba **Basics**:
   - **Resource group**: `rg-internal-dev-brs`
   - **Name**: `vnet-internal-dev-brs`
   - **Region**: `Brazil South`
3. Aba **IP addresses**:
   - **Address space**: `10.10.0.0/16`
   - Apague a subnet `default`.
   - **+ Add subnet**:
     - **Name**: `snet-apim-dev`
     - **Subnet address range**: `10.10.1.0/24`
     - **NAT gateway**: None
     - **Service endpoints**: nenhum (a menos que use force tunneling)
     - **Subnet delegation**: **None** ⚠️ (essencial!)
4. **Review + create** → **Create**.

## 3.5 Criar o Network Security Group

1. Procure por **Network security groups** → **Create**.
2. Preencha:
   - **Resource group**: `rg-internal-dev-brs`
   - **Name**: `nsg-apim-dev-brs`
   - **Region**: `Brazil South`
3. **Review + create** → **Create**.

### 3.5.1 Adicionar regras inbound

Na lâmina do NSG → **Inbound security rules** → **+ Add**:

| Name | Priority | Source | Source service tag | Source port | Destination | Dest. port | Protocol | Action |
|------|----------|--------|--------------------|-------------|-------------|------------|----------|--------|
| `Inbound-ApiManagement-Mgmt-3443` | 100 | `Service Tag` | `ApiManagement` | `*` | `VirtualNetwork` | `3443` | TCP | Allow |
| `Inbound-AzureLoadBalancer-6390` | 110 | `Service Tag` | `AzureLoadBalancer` | `*` | `VirtualNetwork` | `6390` | TCP | Allow |

### 3.5.2 Adicionar regras outbound

Na lâmina do NSG → **Outbound security rules** → **+ Add**:

| Name | Priority | Source | Source port | Destination service tag | Dest. port | Protocol |
|------|----------|--------|-------------|-------------------------|-----------|----------|
| `Outbound-Storage-443` | 100 | `VirtualNetwork` | `*` | `Storage` | `443` | TCP |
| `Outbound-SQL-1433` | 110 | `VirtualNetwork` | `*` | `SQL` | `1433` | TCP |
| `Outbound-KeyVault-443` | 120 | `VirtualNetwork` | `*` | `AzureKeyVault` | `443` | TCP |
| `Outbound-AzureMonitor` | 130 | `VirtualNetwork` | `*` | `AzureMonitor` | `443,1886` | TCP |
| `Outbound-Internet-80` | 140 | `VirtualNetwork` | `*` | `Internet` | `80` | TCP |

### 3.5.3 Associar o NSG à subnet

1. Na lâmina do NSG → **Subnets** → **+ Associate**.
2. Selecione `vnet-internal-dev-brs` → `snet-apim-dev`.
3. Clique **OK**.

## 3.6 Criar o API Management

1. Procure por **API Management services** → **Create**.
2. Aba **Basics**:
   - **Resource group**: `rg-internal-dev-brs`
   - **Region**: `Brazil South`
   - **Resource name**: `apim-internal-owner-dev` (substitua `owner` pelo seu identificador único)
   - **Organization name**: `Ednei Monteiro`
   - **Administrator email**: seu e-mail
   - **Pricing tier**: `Developer (no SLA)`
3. Aba **Monitoring**:
   - **Application Insights**: marque e selecione `appi-internal-dev-brs`.
4. Aba **Virtual network**:
   - **Connectivity type**: `Virtual network`
   - **Virtual network type**: `Internal`
   - Selecione `vnet-internal-dev-brs` → `snet-apim-dev`.
5. Aba **Managed identity**:
   - **System assigned**: `On`.
6. **Review + create** → **Create**.

> ⏰ **A provisão leva 30–45 minutos.** Vá tomar um café. ☕

## 3.7 Após a provisão — próximos passos

Vá em **API Management** → seu APIM → **Overview** e anote:

- **Public virtual IP address** (saída — só relevante para chamadas outbound do APIM)
- **Private virtual IP address** (este é o IP que você vai usar nos registros DNS!)

Em seguida, **siga obrigatoriamente** [05-configuracao-dns.md](05-configuracao-dns.md) para configurar **custom domain** em TLD privado — caso contrário, o APIM ficará inalcançável sem hacks no `/etc/hosts`.

> ⚠️ O **test console** no portal **não funciona** em modo Internal. Use o **developer portal** ou faça testes a partir de uma VM dentro da VNet.

---

⬅️ Anterior: [Arquitetura](02-arquitetura.md) | ➡️ Próximo: [Tutorial — Terraform](04-tutorial-terraform.md)
