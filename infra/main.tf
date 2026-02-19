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

resource "azurerm_resource_group" "DefaultAnalayticsWorkspace" {
	name     = "DefaultAnalayticsWorkspace-rg"
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
resource "azurerm_storage_account" "dev_fnc_cust_backend" {
  name                     = "devfnccustbackend"
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.common_tags
}


//Create a storage account as netapp inbound storage for blob created event trigger
resource "azurerm_storage_account" "dev_netapp_inbound" {
  name                     = "devnetappinbound"
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.common_tags
}

//Create a blob container for netapp inbound storage
resource "azurerm_storage_container" "dev_netapp_inbound_container" {
  name                  = "netapp-inbound-docs"
  storage_account_id    = azurerm_storage_account.dev_netapp_inbound.id
  container_access_type = "private"
}

//Create a blob container for FlexConsumption storage
resource "azurerm_storage_container" "dev_cust_filter_func_container" {
  name                  = "function-app-storage"
  storage_account_id    = azurerm_storage_account.dev_fnc_cust_backend.id
  container_access_type = "private"
}

//Create Function App service plan
resource "azurerm_service_plan" "dev_cust_filter_func_plan" {
  name                = "devfncappplan4cust"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  os_type             = "Linux"
  sku_name            = "FC1"
}

//Create Log Analytics Workspace for Application Insights
resource "azurerm_log_analytics_workspace" "dev_analytics_workspace" {
  name                = "dev-cust-filter-func-logs"
  resource_group_name = azurerm_resource_group.DefaultAnalayticsWorkspace.name
  location            = azurerm_resource_group.DefaultAnalayticsWorkspace.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

//Create Application Insights for Function App monitoring
resource "azurerm_application_insights" "dev_cust_filter_func_insights" {
  name                       = "dev-cust-filter-func-insights"
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  application_type           = "web"
  workspace_id               = azurerm_log_analytics_workspace.dev_analytics_workspace.id
  tags                       = local.common_tags
}

// Create Azure function with FlexConsumption plan
resource "azurerm_function_app_flex_consumption" "dev_cust_filter_func" {
  name                = "devfncapp4cust"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  service_plan_id     = azurerm_service_plan.dev_cust_filter_func_plan.id
  tags                = local.common_tags

  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.dev_fnc_cust_backend.primary_blob_endpoint}${azurerm_storage_container.dev_cust_filter_func_container.name}"
  storage_authentication_type = "StorageAccountConnectionString"
  storage_access_key          = azurerm_storage_account.dev_fnc_cust_backend.primary_access_key
  
  runtime_name    = "python"
  runtime_version = "3.13"
  
  maximum_instance_count = 10
  instance_memory_in_mb  = 2048

  app_settings = {
    APPINSIGHTS_INSTRUMENTATIONKEY             = azurerm_application_insights.dev_cust_filter_func_insights.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING       = azurerm_application_insights.dev_cust_filter_func_insights.connection_string
    ApplicationInsightsAgent_EXTENSION_VERSION  = "~3"
  }

  site_config {}
}

// Event Grid subscription for BlobCreated events on the storage account
resource "azurerm_eventgrid_system_topic" "dev_storage_events_topic" {
  name                   = "dev-storage-events-topic"
  resource_group_name    = azurerm_resource_group.this.name
  location               = azurerm_resource_group.this.location
  source_resource_id     = azurerm_storage_account.dev_netapp_inbound.id
  topic_type             = "Microsoft.Storage.StorageAccounts"
}


resource "azurerm_eventgrid_system_topic_event_subscription" "dev_storage_eventgrid_blobcreated" {
  name  = "dev-storage-blobcreated-subscription"
  system_topic = azurerm_eventgrid_system_topic.dev_storage_events_topic.name
  resource_group_name = azurerm_resource_group.this.name

  included_event_types = [
    "Microsoft.Storage.BlobCreated"
  ]

  azure_function_endpoint {
    function_id = "${azurerm_function_app_flex_consumption.dev_cust_filter_func.id}/functions/NetappBlobCreateFunction"
  }
}