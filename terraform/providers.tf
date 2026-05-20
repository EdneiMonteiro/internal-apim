terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    pkcs12 = {
      source  = "chilicat/pkcs12"
      version = "~> 0.2"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      # App Insights cria recursos implícitos (smart detector alert rules) que
      # não ficam no state do Terraform. Sem isso, `terraform destroy` falha
      # com "Resource Group still contains Resources".
      prevent_deletion_if_contains_resources = false
    }
  }

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}
