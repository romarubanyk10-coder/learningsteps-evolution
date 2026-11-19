output "resource_group_name" {
  description = "Name of the project resource group"
  value       = azurerm_resource_group.main.name
}
output "vnet_name" {
  description = "Name of the project virtual network"
  value       = azurerm_virtual_network.main.name
}
output "acr_login_server" {
  description = "Address of the container registry"
  value       = azurerm_container_registry.main.login_server
}

output "aks_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_node_resource_group" {
  description = "Resource group that AKS manages for nodes, disks and load balancers"
  value       = azurerm_kubernetes_cluster.main.node_resource_group
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL, used later for workload identity"
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "postgres_fqdn" {
  description = "Private DNS name of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "foundry_endpoint" {
  description = "Endpoint of the AI Services (Foundry) account"
  value       = azurerm_cognitive_account.foundry.endpoint
}

output "foundry_deployment_name" {
  description = "Name of the model deployment the app calls"
  value       = azurerm_cognitive_deployment.gpt5mini.name
}