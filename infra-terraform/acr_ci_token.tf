# Access for the GitHub Actions pipeline to the registry.
# The lab does not allow service principals, so the pipeline signs in to ACR
# with a repository-scoped token: it may read and write ONLY the repository
# learningsteps-api. It cannot delete images, see other repositories or
# change the registry.
#
# Terraform creates the scope map and the token, but NOT the password:
# the password is generated once with the Azure CLI and piped straight into
# a GitHub secret, so it never appears in the Terraform state, the terminal or git.

resource "azurerm_container_registry_scope_map" "ci_push" {
  name                    = "ci-push-learningsteps-api"
  container_registry_name = azurerm_container_registry.main.name
  resource_group_name     = azurerm_resource_group.main.name
  description             = "GitHub Actions: push and pull learningsteps-api only"
  actions = [
    "repositories/learningsteps-api/content/read",
    "repositories/learningsteps-api/content/write",
  ]
}

resource "azurerm_container_registry_token" "ci_push" {
  name                    = "github-actions"
  container_registry_name = azurerm_container_registry.main.name
  resource_group_name     = azurerm_resource_group.main.name
  scope_map_id            = azurerm_container_registry_scope_map.ci_push.id
}
