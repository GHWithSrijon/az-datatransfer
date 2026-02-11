output "resource_group_name" {
  value       = azurerm_resource_group.this.name
  description = "Name of the created resource group."
}

output "storage_account_name" {
  value       = azurerm_storage_account.backend_storage_account_1.name
  description = "Name of the data storage account."
}

output "function_app_name" {
  value       = azurerm_linux_function_app.function_app.name
  description = "Name of the Function App handling storage events."
}
