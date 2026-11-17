provider "azurerm" {
  features {}

  # subscription_id is read from the ARM_SUBSCRIPTION_ID environment variable,
  # so the subscription ID never lands in git.

  resource_providers_to_register = [
    "Microsoft.CognitiveServices",
    "Microsoft.ContainerRegistry",
    "Microsoft.ContainerService",
    "Microsoft.DBforPostgreSQL",
    "Microsoft.KeyVault",
    "Microsoft.ManagedIdentity",
    "Microsoft.Network",
  ]
}