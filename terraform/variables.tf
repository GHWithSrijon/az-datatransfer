variable "subscription_id" {
  description = "Azure subscription ID used for deployment."
  type        = string
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "Australia East"
}

variable "resource_group_name" {
  description = "Name of the resource group."
  type        = string
  default     = "rg-terraform-vm"
}

variable "vm_name" {
  description = "Name of the virtual machine."
  type        = string
  default     = "oc-vm"
}

variable "admin_username" {
  description = "Admin username for the VM."
  type        = string
  default     = "ocuser"
}


variable "vm_size" {
  description = "Azure VM SKU."
  type        = string
  default     = "Standard_B2s"
}

variable "address_space" {
  description = "CIDR block for the virtual network."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_prefix" {
  description = "CIDR block for the subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH to the VM."
  type        = string
  default     = "0.0.0.0/0"
}

variable "cloud_init_file" {
  description = "Path to a cloud-init YAML file. Set to null to disable custom_data."
  type        = string
  default     = null
}

variable "storage_account_name_prefix" {
  description = "Prefix for the storage account name. Only lowercase letters and numbers are kept."
  type        = string
  default     = "ocsa"
}

variable "tags" {
  description = "Tags applied to all supported resources."
  type        = map(string)
  default = {
    managed_by = "terraform"
    project    = "azure-vm"
  }
}
