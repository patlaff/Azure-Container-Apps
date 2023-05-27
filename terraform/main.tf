resource "azurerm_resource_group" "this" {
  name     = format("%s-%s-%s", local.common_name, var.env, "rg")
  location = local.location
  tags     = local.common_tags
}

resource "azurerm_virtual_network" "this" {
  name                = format("%s-%s-%s", local.common_name, var.env, "vnet")
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.network.address_space]
  tags                = local.common_tags
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_subnet" "this" {
  name                 = format("%s-%s-%s", local.common_name, var.env, "sn")
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.subnet_prefix]
  #service_endpoints    = ["Microsoft.KeyVault"]
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = format("%s-%s-%s", local.common_name, var.env, "la")
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

# resource "azurerm_container_registry" "this" {
#   name                = replace(format("%s-%s-%s", local.common_name, var.env, "acr"),"-","")
#   resource_group_name = azurerm_resource_group.this.name
#   location            = azurerm_resource_group.this.location
#   sku                 = "Premium"
#   admin_enabled       = false
#   georeplications {
#     location                = "East US"
#     zone_redundancy_enabled = true
#     tags                    = local.common_tags
#   }
#   georeplications {
#     location                = "North Europe"
#     zone_redundancy_enabled = true
#     tags                    = local.common_tags
#   }
# }

resource "azurerm_storage_account" "this" {
  name                     = replace(format("%s-%s-%s", local.common_name, var.env, "stg"), "-", "")
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.common_tags
}

resource "azurerm_key_vault" "this" {
  name                       = format("%s-%s-%s", local.common_name, var.env, "kv")
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  tags                       = local.common_tags
}

# resource "azurerm_role_assignment" "TF_KV_Secrets_Officer" {
#   scope                = azurerm_key_vault.this.id
#   role_definition_name = "Key Vault Secrets Officer"
#   principal_id         = data.azurerm_client_config.current.object_id
# }

resource "azurerm_role_assignment" "CA_KV_Secrets_Officer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}

resource "azurerm_container_app_environment" "this" {
  name                       = format("%s-%s-%s", local.common_name, var.env, "env")
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  #infrastructure_subnet_id   = azurerm_subnet.this.id
  tags = local.common_tags
}

resource "azurerm_storage_share" "this" {
  name                 = local.data_volume_name
  storage_account_name = azurerm_storage_account.this.name
  quota                = 50
  # acl {

  # }
}

resource "azurerm_container_app_environment_storage" "this" {
  name                         = local.data_volume_name
  container_app_environment_id = azurerm_container_app_environment.this.id
  account_name                 = azurerm_storage_account.this.name
  share_name                   = azurerm_storage_share.this.name
  access_key                   = azurerm_storage_account.this.primary_access_key
  access_mode                  = "ReadWrite"
}

resource "azurerm_user_assigned_identity" "this" {
  name                = format("%s-%s-%s", local.common_name, var.env, "msi")
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.common_tags
}

resource "azurerm_container_app" "this" {
  name                         = format("%s-%s-%s", local.common_name, var.env, "ca")
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"
  tags                         = local.common_tags
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.this.id]
  }
  secret {
    name  = "foundry-admin-key"
    value = data.azurerm_key_vault_secret.this["foundry-admin-key"].value
  }
  secret {
    name  = "foundry-password"
    value = data.azurerm_key_vault_secret.this["foundry-password"].value
  }
  secret {
    name  = "foundry-username"
    value = data.azurerm_key_vault_secret.this["foundry-username"].value
  }
  secret {
    name  = "foundry-license-key"
    value = data.azurerm_key_vault_secret.this["foundry-license-key"].value
  }
  # ingress {
  #   external_enabled = true
  #   target_port      = 30000
  #   traffic_weight {
  #     percentage = 100
  #   }
  # }
  template {
    min_replicas = 1
    max_replicas = 1
    container {
      name   = "foundryvtt"
      image  = "felddy/foundryvtt"
      cpu    = 0.25
      memory = "0.5Gi"
      volume_mounts {
        name = azurerm_container_app_environment_storage.this.name
        path = "/data"
      }
      env {
        name        = "FOUNDRY_ADMIN_KEY"
        secret_name = "foundry-admin-key"
      }
      env {
        name        = "FOUNDRY_PASSWORD"
        secret_name = "foundry-password"
      }
      env {
        name        = "FOUNDRY_USERNAME"
        secret_name = "foundry-username"
      }
      env {
        name        = "FOUNDRY_LICENSE_KEY"
        secret_name = "foundry-license-key"
      }
      # env {
      #   name  = "FOUNDRY_UID"
      #   value = "1000"
      # }
      # env {
      #   name  = "FOUNDRY_GID"
      #   value = "1002"
      # }
      readiness_probe {
        transport = "HTTP"
        port      = 80
      }
      liveness_probe {
        transport = "HTTP"
        port      = 80
      }
      startup_probe {
        transport = "HTTP"
        port      = 80
      }
    }
    volume {
      name         = azurerm_container_app_environment_storage.this.name
      storage_name = azurerm_container_app_environment_storage.this.name
      storage_type = "AzureFile"
    }
  }
}