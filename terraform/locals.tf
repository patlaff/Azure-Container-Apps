locals {
  location    = "East US 2"
  common_name = "laff-ca"
  common_tags = {
    owner     = "Pat Lafferty"
    managedBy = "Terraform"
  }

  foundry_admin_key = data.azurerm_key_vault_secret.this["foundry-admin-key"].id

}