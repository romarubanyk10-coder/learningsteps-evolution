resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project}-evolution"
  location = var.location
  tags     = var.tags
}