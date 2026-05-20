variable "subscription_id" {
  description = "ID da Azure Subscription onde os recursos serão provisionados."
  type        = string
}

variable "tenant_id" {
  description = "ID do Azure AD Tenant."
  type        = string
}

variable "location" {
  description = "Região do Azure (ex: brazilsouth, eastus)."
  type        = string
  default     = "brazilsouth"
}

variable "location_short" {
  description = "Abreviação da região usada na nomenclatura (ex: brs, eus)."
  type        = string
  default     = "brs"
}

variable "workload" {
  description = "Nome curto do workload, usado nos nomes dos recursos. Use algo SEM duplicação com a abreviação CAF do recurso (ex: 'internal', não 'internalapim')."
  type        = string
  default     = "internal"
}

variable "environment" {
  description = "Ambiente (dev, hml, prd)."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Identificador do owner — usado para garantir unicidade global do nome do APIM."
  type        = string
  default     = "owner"
}

variable "publisher_name" {
  description = "Nome do publisher exibido no portal do APIM."
  type        = string
}

variable "publisher_email" {
  description = "E-mail do publisher (recebe notificações administrativas)."
  type        = string
}

variable "apim_sku" {
  description = "SKU do APIM. Apenas Developer_N e Premium_N suportam VNet integration."
  type        = string
  default     = "Developer_1"

  validation {
    condition     = can(regex("^(Developer|Premium)_[0-9]+$", var.apim_sku))
    error_message = "Para modo Internal use apenas SKU Developer_N ou Premium_N."
  }
}

variable "vnet_address_space" {
  description = "Address space da VNet."
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "apim_subnet_prefix" {
  description = "Prefixo CIDR da subnet dedicada ao APIM (mínimo /29 recomendado)."
  type        = string
  default     = "10.10.1.0/24"
}

variable "custom_domain" {
  description = <<-EOT
    Domínio privado para os hostnames do APIM em modo Internal.
    Use um TLD reservado para uso privado (`.internal` é reservado pela ICANN, RFC 6762/RFC 8375 recomenda `.home.arpa` ou organizacional).
    NUNCA use `azure-api.net` ou domínios públicos sob seu controle aqui — esse domínio será criado como Private DNS Zone na VNet.
  EOT
  type        = string
  default     = "api.internal"
}

variable "cert_password" {
  description = "Senha do PFX self-signed gerado para o custom domain. Para produção, referencie um Key Vault em vez de hardcoded."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags padrão aplicadas a todos os recursos."
  type        = map(string)
  default = {
    workload    = "internal-apim"
    environment = "dev"
    managedBy   = "terraform"
    purpose     = "tutorial"
  }
}
