resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project}-evolution"
  location = var.location
  tags     = var.tags

  # Azure adds a "created-on" tag on its own. It is not ours, so Terraform must not remove it.
  lifecycle {
    ignore_changes = [tags["created-on"]]
  }
}
