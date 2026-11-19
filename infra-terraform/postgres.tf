ephemeral "random_password" "postgres_admin" {
  length  = 32
  special = false
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                          = "psql-${var.project}-evo"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  version                       = "16"
  sku_name                      = var.postgres_sku
  zone                          = var.postgres_zone
  storage_mb                    = 32768
  backup_retention_days         = 7
  geo_redundant_backup_enabled  = false
  delegated_subnet_id           = azurerm_subnet.db.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id
  public_network_access_enabled = false
  tags                          = var.tags

  administrator_login               = "psqladmin"
  administrator_password_wo         = ephemeral.random_password.postgres_admin.result
  administrator_password_wo_version = 1

  authentication {
    password_auth_enabled         = true
    active_directory_auth_enabled = false
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]

  lifecycle {
    ignore_changes = [zone, tags["created-on"]]
  }
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = "learning_journal"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_key_vault_secret" "postgres_admin_password" {
  name         = "postgres-admin-password"
  key_vault_id = azurerm_key_vault.main.id
  value_wo     = ephemeral.random_password.postgres_admin.result
  # Version 2: the first apply wrote a password here, but the server failed to create
  # (SkuNotAvailable). The retry generates a new password, so the secret must be rewritten too.
  value_wo_version = 2
  content_type     = "password"
  expiration_date  = "2027-03-31T00:00:00Z"

  # Write the secret only after the server exists, so a failed server create never leaves
  # a password in Key Vault that the server does not have.
  depends_on = [
    azurerm_role_assignment.me_kv_secrets_officer,
    azurerm_postgresql_flexible_server.main,
  ]
}

resource "azurerm_postgresql_flexible_server_configuration" "log_connections" {
  name      = "log_connections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

resource "azurerm_postgresql_flexible_server_configuration" "log_checkpoints" {
  name      = "log_checkpoints"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

resource "azurerm_postgresql_flexible_server_configuration" "connection_throttling" {
  name      = "connection_throttle.enable"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}
