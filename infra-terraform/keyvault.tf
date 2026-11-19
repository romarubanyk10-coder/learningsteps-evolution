data "azurerm_client_config" "current" {}

# AZU-0016 accepted: purge protection would block re-creating a vault with the same name for
# 7 days, which breaks the destroy -> apply recovery test. Soft delete (7 days) stays on.
#trivy:ignore:AVD-AZU-0016
resource "azurerm_key_vault" "main" {
  name                          = "kv-${var.project}-evo"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  soft_delete_retention_days    = 7
  purge_protection_enabled      = false
  public_network_access_enabled = true
  tags                          = var.tags

  network_acls {
    default_action             = "Deny"
    bypass                     = "None"
    ip_rules                   = var.kv_allowed_ips
    virtual_network_subnet_ids = [azurerm_subnet.aks.id]
  }

  lifecycle {
    ignore_changes = [tags["created-on"]]
  }
}

resource "azurerm_role_assignment" "me_kv_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}