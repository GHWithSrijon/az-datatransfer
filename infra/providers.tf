terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}

  # Optionally pin subscription and tenant, or rely on `az login`
  subscription_id = "31181d1b-e311-4a57-b199-f2c0c540fe95"
  tenant_id       = "20d726c9-5561-419a-b9d2-46b2006bf0c5"
}
