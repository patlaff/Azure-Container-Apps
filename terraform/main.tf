resource "azurerm_resource_group" "this" {
  name     = format("%s-%s-%s", local.common_name, var.env, "rg")
  location = local.location
  tags     = local.common_tags
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

resource "azurerm_container_app_environment" "this" {
  name                       = format("%s-%s-%s", local.common_name, var.env, "env")
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
}

resource "azurerm_container_app" "this" {
  name                         = format("%s-%s-%s", local.common_name, var.env, "ca")
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"
  tags                         = local.common_tags
  template {
    container {
      name   = "examplecontainerapp"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }
}