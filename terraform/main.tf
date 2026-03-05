resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

resource "random_string" "storage_suffix" {
  length  = 10
  special = false
  upper   = false
}

locals {
  base_name            = "${var.vm_name}-${random_string.suffix.result}"
  storage_account_name = substr(lower(replace("${var.storage_account_name_prefix}${random_string.storage_suffix.result}", "/[^0-9a-z]/", "")), 0, 24)
  storage_containers   = toset(["inbound", "manifest", "outbound"])
  ssh_dir              = "${path.root}/../.ssh"
  ssh_private_key      = "${local.ssh_dir}/${local.base_name}"
  ssh_public_key       = "${local.ssh_private_key}.pub"
}

resource "terraform_data" "ssh_dir" {
  provisioner "local-exec" {
    command = "mkdir -p '${local.ssh_dir}' && chmod 700 '${local.ssh_dir}'"
  }
}

resource "tls_private_key" "vm" {
  algorithm = "ED25519"
}

resource "local_sensitive_file" "ssh_private_key" {
  filename             = local.ssh_private_key
  content              = tls_private_key.vm.private_key_openssh
  file_permission      = "0600"
  directory_permission = "0700"

  depends_on = [terraform_data.ssh_dir]
}

resource "local_file" "ssh_public_key" {
  filename             = local.ssh_public_key
  content              = tls_private_key.vm.public_key_openssh
  file_permission      = "0644"
  directory_permission = "0700"

  depends_on = [terraform_data.ssh_dir]
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "${local.base_name}-vnet"
  address_space       = [var.address_space]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  name                 = "${local.base_name}-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_prefix]
}

resource "azurerm_storage_account" "this" {
  name                            = local.storage_account_name
  resource_group_name             = azurerm_resource_group.this.name
  location                        = azurerm_resource_group.this.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false
  min_tls_version                 = "TLS1_2"
  tags                            = var.tags
}

resource "azurerm_storage_container" "this" {
  for_each = local.storage_containers

  name                  = each.value
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "${local.base_name}-blob-link"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.this.id
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "storage_blob" {
  name                = "${local.base_name}-st-pe"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.this.id
  tags                = var.tags

  private_service_connection {
    name                           = "${local.base_name}-st-psc"
    private_connection_resource_id = azurerm_storage_account.this.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "blob-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}

resource "azurerm_public_ip" "this" {
  name                = "${local.base_name}-pip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_security_group" "this" {
  name                = "${local.base_name}-nsg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  security_rule {
    name                       = "allow-ssh"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ssh_cidr
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "this" {
  name                = "${local.base_name}-nic"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.this.id
  }
}

resource "azurerm_network_interface_security_group_association" "this" {
  network_interface_id      = azurerm_network_interface.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}

resource "azurerm_linux_virtual_machine" "this" {
  name                = local.base_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  size                = var.vm_size
  admin_username      = var.admin_username
  custom_data         = var.cloud_init_file == null ? null : filebase64(var.cloud_init_file)
  network_interface_ids = [
    azurerm_network_interface.this.id,
  ]
  disable_password_authentication = true
  tags                            = var.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.vm.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}
