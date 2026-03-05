output "resource_group_name" {
  description = "Resource group containing the VM."
  value       = azurerm_resource_group.this.name
}

output "vm_name" {
  description = "Deployed virtual machine name."
  value       = azurerm_linux_virtual_machine.this.name
}

output "public_ip_address" {
  description = "Public IP address assigned to the VM."
  value       = azurerm_public_ip.this.ip_address
}

output "ssh_command" {
  description = "Convenience SSH command."
  value       = "ssh -i ${local.ssh_private_key} ${var.admin_username}@${azurerm_public_ip.this.ip_address}"
}

output "ssh_private_key_path" {
  description = "Path to the generated SSH private key."
  value       = local.ssh_private_key
}

output "storage_account_name" {
  description = "Provisioned storage account name."
  value       = azurerm_storage_account.this.name
}

output "storage_container_names" {
  description = "Provisioned private blob container names."
  value       = sort([for container in azurerm_storage_container.this : container.name])
}

output "storage_private_endpoint_id" {
  description = "Private endpoint resource ID for blob access."
  value       = azurerm_private_endpoint.storage_blob.id
}
