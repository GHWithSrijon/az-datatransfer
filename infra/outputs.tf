output "ssh_private_key_pem" {
  value     = tls_private_key.ssh.private_key_pem
  sensitive = true
}

output "resource_group" {
  value = azurerm_resource_group.rg.name
}

output "storage_account_name" {
  value = azurerm_storage_account.dev_netapp_inbound.name
}

output "queue_name" {
  value = azurerm_storage_queue.blob_events_queue.name
}

output "vmss_name" {
  value = azurerm_linux_virtual_machine_scale_set.vmss.name
}

output "bastion_host" {
  value = azurerm_bastion_host.bastion.name
}
