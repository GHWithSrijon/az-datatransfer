// Local values and resource group
locals {
	resource_group_name = "rg-${var.project_name}-${var.environment}"

	common_tags = merge({
		Project     = var.project_name
		Environment = var.environment
	}, var.tags)
}

############################
# RESOURCE GROUP
############################

resource "azurerm_resource_group" "rg" {
	name     = local.resource_group_name
	location = var.location
	tags     = local.common_tags
}

resource "azurerm_resource_group" "DefaultAnalayticsWorkspace" {
	name     = "DefaultAnalayticsWorkspace-rg"
	location = var.location
	tags     = local.common_tags
}

############################
# NETWORKING (VNET + SUBNETS)
############################

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.project_name}-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet_workers" {
  name                 = "subnet-workers"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/25"]
}

resource "azurerm_subnet" "subnet_private_endpoints" {
  name                 = "subnet-private-endpoints"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/25"]
}

resource "azurerm_subnet" "subnet_bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/25"]
}

############################
# STORAGE ACCOUNT + QUEUE
############################

//Create a storage account as netapp inbound storage for blob created event trigger
resource "azurerm_storage_account" "dev_netapp_inbound" {
  name                     = "sainbound${var.environment}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
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

// Create storage queue for blob events
resource "azurerm_storage_queue" "blob_events_queue" {
  name                 = "queue-blob-events"
  storage_account_id   = azurerm_storage_account.dev_netapp_inbound.id
}


############################
# LOG ANALYTICS WORKSPACE + APPLICATION INSIGHTS + FUNCTION APP
############################
resource "azurerm_log_analytics_workspace" "dev_analytics_workspace" {
  name                = "ws-${var.project_name}-logs-${var.environment}"
  resource_group_name = azurerm_resource_group.DefaultAnalayticsWorkspace.name
  location            = azurerm_resource_group.DefaultAnalayticsWorkspace.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}


############################
# PUBLIC IP + BASTION
############################

# resource "azurerm_public_ip" "bastion_pip" {
#   name                = "pip-bastion-${var.project_name}-${var.environment}"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name
#   allocation_method   = "Static"
#   sku                 = "Standard"
# }

# resource "azurerm_bastion_host" "bastion" {
#   name                = "bastion-${var.project_name}-${var.environment}"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name

#   ip_configuration {
#     # Name must be "AzureBastionSubnet" 
#     name                 = "AzureBastionSubnet"
#     subnet_id            = azurerm_subnet.subnet_bastion.id
#     public_ip_address_id = azurerm_public_ip.bastion_pip.id
#   }
# }

############################
# VM SCALE SET (WORKERS)
############################

# SSH key for admin user
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

locals {
  admin_username = "azureuser"

  cloud_init = templatefile("${path.module}/templates/worker-cloud-init.tftpl", {
    account_name = azurerm_storage_account.dev_netapp_inbound.name
    queue_name   = azurerm_storage_queue.blob_events_queue.name
  })
}

resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                = "vmss-${var.project_name}-workers"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard_D2s_v3"
  instances           = 1
  overprovision       = false
  admin_username      = local.admin_username

  admin_ssh_key {
    username   = local.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }

  source_image_reference {
    publisher = "anarion-technologies"
    offer     = "Ubuntu 24.04 LTS - x64 Gen1"
    sku       = "22_04-lts"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  network_interface {
    name    = "nic-${var.project_name}-workers"
    primary = true

    ip_configuration {
      name                                   = "ipconfig-${var.project_name}-workers"
      primary                                = true
      subnet_id                              = azurerm_subnet.subnet_workers.id
      load_balancer_backend_address_pool_ids = []
    }
  }

  identity {
    type = "SystemAssigned"
  }

  upgrade_mode = "Automatic"

  custom_data = base64encode(local.cloud_init)
}

############################
# RBAC: VMSS → STORAGE QUEUE
############################

# data "azurerm_subscription" "current" {}

resource "azurerm_role_assignment" "vmss_queue_contrib" {
  scope                = azurerm_storage_account.dev_netapp_inbound.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_linux_virtual_machine_scale_set.vmss.identity[0].principal_id
}


# // Event Grid subscription for BlobCreated events on the storage account
# resource "azurerm_eventgrid_system_topic" "dev_storage_events_topic" {
#   name                   = "dev-storage-events-topic"
#   resource_group_name    = azurerm_resource_group.rg.name
#   location               = azurerm_resource_group.rg.location
#   source_resource_id     = azurerm_storage_account.dev_netapp_inbound.id
#   topic_type             = "Microsoft.Storage.StorageAccounts"
# }


# resource "azurerm_eventgrid_system_topic_event_subscription" "dev_storage_eventgrid_blobcreated" {
#   name  = "dev-storage-blobcreated-subscription"
#   system_topic = azurerm_eventgrid_system_topic.dev_storage_events_topic.name
#   resource_group_name = azurerm_resource_group.rg.name

#   included_event_types = [
#     "Microsoft.Storage.BlobCreated"
#   ]

#   azure_function_endpoint {
#     function_id = "${azurerm_function_app_flex_consumption.dev_cust_filter_func.id}/functions/NetappBlobCreateFunction"
#   }
# }