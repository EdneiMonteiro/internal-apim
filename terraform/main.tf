locals {
  base_name = "${var.workload}-${var.environment}-${var.location_short}"

  rg_name     = "rg-${local.base_name}"
  vnet_name   = "vnet-${local.base_name}"
  subnet_name = "snet-apim-${var.environment}"
  nsg_name    = "nsg-apim-${var.environment}-${var.location_short}"
  log_name    = "log-${local.base_name}"
  appi_name   = "appi-${local.base_name}"

  # Nome do APIM precisa ser globalmente único. Pattern: apim-<workload>-<owner>-<env>.
  # Workload "internal" + owner garantem unicidade SEM duplicar a abreviação "apim".
  apim_name = "apim-${var.workload}-${var.owner}-${var.environment}"

  # Hostnames customizados (dentro do TLD privado var.custom_domain)
  apim_hostnames = {
    gateway    = "apim.${var.custom_domain}"
    developer  = "developer.${var.custom_domain}"
    management = "management.${var.custom_domain}"
    scm        = "scm.${var.custom_domain}"
  }
}

resource "azurerm_resource_group" "this" {
  name     = local.rg_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = local.log_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "this" {
  name                = local.appi_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  workspace_id        = azurerm_log_analytics_workspace.this.id
  application_type    = "web"
  tags                = var.tags
}

resource "azurerm_virtual_network" "this" {
  name                = local.vnet_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "apim" {
  name                 = local.subnet_name
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.apim_subnet_prefix]
}

resource "azurerm_network_security_group" "apim" {
  name                = local.nsg_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  # ===== Inbound rules =====

  security_rule {
    name                       = "Inbound-ApiManagement-Mgmt-3443"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3443"
    source_address_prefix      = "ApiManagement"
    destination_address_prefix = "VirtualNetwork"
    description                = "Management endpoint do APIM (Portal/PowerShell)"
  }

  security_rule {
    name                       = "Inbound-AzureLoadBalancer-6390"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6390"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "VirtualNetwork"
    description                = "Azure Infrastructure Load Balancer"
  }

  # ===== Outbound rules =====

  security_rule {
    name                       = "Outbound-Storage-443"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "Storage"
    description                = "Dependência core: Azure Storage"
  }

  security_rule {
    name                       = "Outbound-SQL-1433"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "SQL"
    description                = "Dependência core: Azure SQL"
  }

  security_rule {
    name                       = "Outbound-KeyVault-443"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "AzureKeyVault"
    description                = "Dependência core: Azure Key Vault"
  }

  security_rule {
    name                       = "Outbound-AzureMonitor"
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "1886"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "AzureMonitor"
    description                = "Publicação de logs/metrics/Application Insights"
  }

  security_rule {
    name                       = "Outbound-Internet-80-CertValidation"
    priority                   = 140
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "Internet"
    description                = "Validação de certificados Microsoft/customer-managed"
  }
}

resource "azurerm_subnet_network_security_group_association" "apim" {
  subnet_id                 = azurerm_subnet.apim.id
  network_security_group_id = azurerm_network_security_group.apim.id
}

resource "azurerm_api_management" "this" {
  name                = local.apim_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = var.apim_sku

  virtual_network_type = "Internal"

  virtual_network_configuration {
    subnet_id = azurerm_subnet.apim.id
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags

  depends_on = [
    azurerm_subnet_network_security_group_association.apim
  ]
}

resource "azurerm_api_management_logger" "appi" {
  name                = "appi-logger"
  api_management_name = azurerm_api_management.this.name
  resource_group_name = azurerm_resource_group.this.name
  resource_id         = azurerm_application_insights.this.id

  application_insights {
    instrumentation_key = azurerm_application_insights.this.instrumentation_key
  }
}

# ============================================================================
# Certificado self-signed para o custom domain
# ----------------------------------------------------------------------------
# Para tutorial usamos um cert self-signed gerado em-runtime pelo Terraform.
# Para PRODUÇÃO, referencie um certificado emitido por uma CA confiável,
# armazenado em Azure Key Vault, via property `key_vault_id`.
# ============================================================================

resource "tls_private_key" "apim" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "apim" {
  private_key_pem = tls_private_key.apim.private_key_pem

  subject {
    common_name  = local.apim_hostnames.gateway
    organization = "Internal APIM Tutorial"
  }

  validity_period_hours = 8760 # 1 ano

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  dns_names = [
    local.apim_hostnames.gateway,
    local.apim_hostnames.developer,
    local.apim_hostnames.management,
    local.apim_hostnames.scm,
  ]
}

resource "pkcs12_from_pem" "apim" {
  password        = var.cert_password
  cert_pem        = tls_self_signed_cert.apim.cert_pem
  private_key_pem = tls_private_key.apim.private_key_pem
}

# ============================================================================
# Custom domain no APIM
# ----------------------------------------------------------------------------
# Substitui os hostnames default *.azure-api.net pelos do TLD privado.
# Com isso, NENHUMA Private DNS Zone toca `azure-api.net`.
# ============================================================================

resource "azurerm_api_management_custom_domain" "this" {
  api_management_id = azurerm_api_management.this.id

  gateway {
    host_name                    = local.apim_hostnames.gateway
    certificate                  = pkcs12_from_pem.apim.result
    certificate_password         = var.cert_password
    negotiate_client_certificate = false
    default_ssl_binding          = true
  }

  developer_portal {
    host_name            = local.apim_hostnames.developer
    certificate          = pkcs12_from_pem.apim.result
    certificate_password = var.cert_password
  }

  management {
    host_name            = local.apim_hostnames.management
    certificate          = pkcs12_from_pem.apim.result
    certificate_password = var.cert_password
  }

  scm {
    host_name            = local.apim_hostnames.scm
    certificate          = pkcs12_from_pem.apim.result
    certificate_password = var.cert_password
  }
}

# ============================================================================
# Private DNS Zone para o TLD privado (api.internal)
# ----------------------------------------------------------------------------
# `internal` é um TLD reservado pela ICANN para uso privado — não pode
# colidir com qualquer DNS público (incluindo azure-api.net).
# ============================================================================

resource "azurerm_private_dns_zone" "internal" {
  name                = var.custom_domain
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "internal" {
  name                  = "link-vnet-${replace(var.custom_domain, ".", "-")}"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.internal.name
  virtual_network_id    = azurerm_virtual_network.this.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_a_record" "apim" {
  for_each = local.apim_hostnames

  # `each.value` é o FQDN completo (ex: apim.api.internal).
  # Removemos o sufixo do zone name para obter o sub-record correto.
  name                = replace(each.value, ".${var.custom_domain}", "")
  zone_name           = azurerm_private_dns_zone.internal.name
  resource_group_name = azurerm_resource_group.this.name
  ttl                 = 300
  records             = azurerm_api_management.this.private_ip_addresses
  tags                = var.tags
}
