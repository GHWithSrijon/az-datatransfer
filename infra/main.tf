// Local values and resource group
locals {
	resource_group_name = var.resource_group_name != "" ? var.resource_group_name : "${var.project_name}-${var.environment}-rg"

	common_tags = merge({
		Project     = var.project_name
		Environment = var.environment
	}, var.tags)
}

resource "azurerm_resource_group" "this" {
	name     = local.resource_group_name
	location = var.location
	tags     = local.common_tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.project_name}-vnet"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "app_subnet" {
  name                 = "${var.project_name}-app-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/25"]
}

resource "azurerm_subnet" "private_endpoints_subnet" {
  name                 = "${var.project_name}-private-endpoints-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/25"]
}

//Create a storage account as backend of the function app
resource "azurerm_storage_account" "backend_storage_account_1" {
  name                     = "${var.project_name}backend1"
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.common_tags
}

//Create Function App service plan
resource "azurerm_service_plan" "function_app_service_plan" {
  name                = "${var.project_name}-functionapp-plan"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  os_type             = "Linux"
  sku_name            = "Y1"
}



// Create Azure function
resource "azurerm_linux_function_app" "function_app" {
  name                       = "${var.project_name}-functionapp"
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  service_plan_id            = azurerm_service_plan.function_app_service_plan.id
  storage_account_name       = azurerm_storage_account.backend_storage_account_1.name
  storage_account_access_key = azurerm_storage_account.backend_storage_account_1.primary_access_key
  tags                       = local.common_tags

  site_config {}
}