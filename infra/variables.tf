variable "project_name" {
  description = "Short name used in resource naming."
  type        = string
  default     = "blobtest"
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "australiaeast"
}

variable "environment" {
  description = "Environment name (e.g. dev, test, prod)."
  type        = string
  default     = "dev"
}


variable "storage_account_sku" {
  description = "SKU for the storage account."
  type        = string
  default     = "Standard_LRS"
}

variable "function_runtime_stack" {
  description = "Runtime stack for the Function App."
  type        = string
  default     = "node"
  validation {
    condition     = contains(["node", "python", "dotnet"], var.function_runtime_stack)
    error_message = "function_runtime_stack must be one of: node, python, dotnet."
  }
}

variable "tags" {
  description = "Common tags for all resources."
  type        = map(string)
  default     = {}
}
