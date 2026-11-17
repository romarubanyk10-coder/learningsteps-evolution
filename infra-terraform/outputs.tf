output "resource_group_name" {
  description = "Name of the project resource group"
  value       = azurerm_resource_group.main.name
}
output "vnet_name" {
  description = "Name of the project virtual network"
  value       = azurerm_virtual_network.main.name
}
