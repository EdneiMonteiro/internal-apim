output "resource_group_name" {
  description = "Nome do Resource Group criado."
  value       = azurerm_resource_group.this.name
}

output "apim_name" {
  description = "Nome do API Management."
  value       = azurerm_api_management.this.name
}

output "apim_gateway_url" {
  description = "URL do gateway (FQDN default)."
  value       = azurerm_api_management.this.gateway_url
}

output "apim_private_ip_addresses" {
  description = "Endereços IP privados (Virtual IP) do APIM. Use estes IPs nos registros DNS."
  value       = azurerm_api_management.this.private_ip_addresses
}

output "apim_default_hostnames" {
  description = "Hostnames default que precisam ser mapeados no DNS interno → Private VIP."
  value = {
    gateway    = "${azurerm_api_management.this.name}.azure-api.net"
    portal     = "${azurerm_api_management.this.name}.portal.azure-api.net"
    developer  = "${azurerm_api_management.this.name}.developer.azure-api.net"
    management = "${azurerm_api_management.this.name}.management.azure-api.net"
    scm        = "${azurerm_api_management.this.name}.scm.azure-api.net"
  }
}

output "vnet_name" {
  description = "Nome da VNet."
  value       = azurerm_virtual_network.this.name
}

output "apim_subnet_id" {
  description = "ID da subnet dedicada ao APIM."
  value       = azurerm_subnet.apim.id
}

output "log_analytics_workspace_id" {
  description = "Workspace ID do Log Analytics."
  value       = azurerm_log_analytics_workspace.this.id
}

output "application_insights_id" {
  description = "ID do Application Insights."
  value       = azurerm_application_insights.this.id
}
