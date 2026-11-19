# --- Identity of the application pods (Workload Identity) ---------------------------------
# The API pods get their own Azure identity instead of keys or passwords.
# Kubernetes gives each pod a signed token for its ServiceAccount; Entra ID trusts tokens
# from this cluster's OIDC issuer for exactly one ServiceAccount (the federated credential)
# and exchanges them for an Azure access token of this identity.

resource "azurerm_user_assigned_identity" "app" {
  name                = "id-${var.project}-app"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  lifecycle {
    ignore_changes = [tags["created-on"]]
  }
}

resource "azurerm_federated_identity_credential" "app" {
  name                      = "fic-learningsteps-api"
  user_assigned_identity_id = azurerm_user_assigned_identity.app.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject                   = "system:serviceaccount:learningsteps:learningsteps-api"
}

# Read secrets (not write, not delete) in this one vault.
resource "azurerm_role_assignment" "app_kv_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

# Call model deployments (not manage them) in this one Foundry account. Used on Day 4.
resource "azurerm_role_assignment" "app_openai_user" {
  scope                = azurerm_cognitive_account.foundry.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}
