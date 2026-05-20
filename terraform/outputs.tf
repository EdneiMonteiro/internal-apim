output "resource_group_name" {
  description = "Nome do Resource Group criado."
  value       = azurerm_resource_group.this.name
}

output "apim_name" {
  description = "Nome do API Management."
  value       = azurerm_api_management.this.name
}

output "apim_private_ip_addresses" {
  description = "Endereços IP privados (Virtual IP) do APIM. Usados nos registros DNS."
  value       = azurerm_api_management.this.private_ip_addresses
}

output "apim_custom_hostnames" {
  description = "Hostnames customizados configurados no APIM (todos resolvidos pela Private DNS Zone)."
  value       = local.apim_hostnames
}

output "apim_gateway_custom_url" {
  description = "URL do gateway usando o custom domain (acessível somente de dentro da VNet)."
  value       = "https://${local.apim_hostnames.gateway}"
}

output "private_dns_zone" {
  description = "Nome da Private DNS Zone privada criada."
  value       = azurerm_private_dns_zone.internal.name
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
