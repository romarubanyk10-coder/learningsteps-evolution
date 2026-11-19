resource "azurerm_cognitive_account" "foundry" {
  name                          = "ais-${var.project}-evo"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  kind                          = "AIServices"
  sku_name                      = "S0"
  custom_subdomain_name         = "ais-${var.project}-evo"
  local_auth_enabled            = false
  public_network_access_enabled = true
  tags                          = var.tags

  network_acls {
    default_action = "Deny"
    bypass         = "None"
    ip_rules       = var.kv_allowed_ips

    virtual_network_rules {
      subnet_id = azurerm_subnet.aks.id
    }
  }

  lifecycle {
    ignore_changes = [tags["created-on"]]
  }
}

resource "azurerm_cognitive_deployment" "gpt5mini" {
  name                 = "gpt-5-mini"
  cognitive_account_id = azurerm_cognitive_account.foundry.id

  model {
    format  = "OpenAI"
    name    = "gpt-5-mini"
    version = "2025-08-07"
  }

  sku {
    name     = "DataZoneStandard"
    capacity = 10
  }
}