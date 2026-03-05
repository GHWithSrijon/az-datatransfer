# Azure VM Terraform Project

This project provisions a single Ubuntu Linux VM in Azure with:

- A resource group
- A virtual network and subnet
- A static public IP
- A network security group allowing SSH
- A NIC associated with the NSG
- A Linux virtual machine using SSH key authentication
- A generated SSH key pair stored in the project `.ssh/` directory
- A private storage account with containers: `inbound`, `manifest`, `outbound`
- A private endpoint for blob access with private DNS integration

## Prerequisites

- Terraform 1.5 or newer
- An Azure subscription
- Azure CLI authenticated with access to the target subscription

## Files

- `providers.tf`: Terraform and provider requirements
- `variables.tf`: Input variables
- `main.tf`: Azure infrastructure resources
- `outputs.tf`: Useful deployment outputs
- `terraform.tfvars.example`: Sample variable values
- `cloud-init.yaml`: Example cloud-init script used by `cloud_init_file`

## Usage

1. Copy the example vars file:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Update `terraform.tfvars` with:

   - Your Azure subscription ID
   - A tighter `allowed_ssh_cidr` than `0.0.0.0/0` if possible
   - `cloud_init_file` path (for example `cloud-init.yaml`)
   - Optional `storage_account_name_prefix` (lowercase letters and numbers recommended)

3. Authenticate to Azure:

   ```bash
   az login
   az account set --subscription "<subscription-id>"
   ```

4. Initialize and deploy:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

   Terraform generates an SSH key pair during apply. The private key is written under `../.ssh/` relative to this folder, and the `ssh_command` output includes the correct `-i` flag.

5. Tear down when finished:

   ```bash
   terraform destroy
   ```

## Notes

- The VM name gets a random suffix to avoid Azure naming collisions.
- This project defaults to Ubuntu 22.04 LTS.
- The generated private key is stored in the repository-level `.ssh/` directory with `0600` permissions.
- SSH is enabled on port 22. Restrict `allowed_ssh_cidr` before applying in anything beyond a throwaway environment.
- Set `cloud_init_file = null` to disable cloud-init custom data.
- Storage account public network access is disabled and containers are private.
