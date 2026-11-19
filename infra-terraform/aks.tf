# Accepted risks (Trivy / AVD), reviewed 2026-11-19. Each is documented in the report.
# AZU-0041 + AZU-0065: the API server stays public because GitHub-hosted runners deploy from
#   changing IP ranges and the lab forbids service principals (no self-hosted runner or VPN).
#   Access still needs a cluster credential and Kubernetes RBAC.
# AZU-0040: no OMS agent / Log Analytics (extra cost); metrics come from Prometheus on Day 5.
# AZU-0066: no Azure Policy add-on; pods are restricted with built-in Pod Security admission instead.
# AZU-0067: OS disk uses Azure platform-managed encryption at rest; customer-managed keys are out of scope.
#trivy:ignore:AVD-AZU-0041
#trivy:ignore:AVD-AZU-0065
#trivy:ignore:AVD-AZU-0040
#trivy:ignore:AVD-AZU-0066
#trivy:ignore:AVD-AZU-0067
resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${var.project}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "aks-${var.project}"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Free"
  node_resource_group = "rg-${var.project}-aks-nodes"
  tags                = var.tags

  default_node_pool {
    name            = "system"
    vm_size         = var.aks_node_vm_size
    node_count      = 1
    vnet_subnet_id  = azurerm_subnet.aks.id
    os_disk_size_gb = 30

    upgrade_settings {
      max_surge = "1"
    }
  }

  node_provisioning_profile {
    mode = "Manual"
  }

  identity {
    type = "SystemAssigned"
  }

  role_based_access_control_enabled = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    pod_cidr            = "192.168.0.0/16"
    service_cidr        = "10.21.0.0/16"
    dns_service_ip      = "10.21.0.10"
    load_balancer_sku   = "standard"
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  lifecycle {
    ignore_changes = [tags["created-on"]]
  }
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                            = azurerm_container_registry.main.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "aks_subnet_network" {
  scope                            = azurerm_subnet.aks.id
  role_definition_name             = "Network Contributor"
  principal_id                     = azurerm_kubernetes_cluster.main.identity[0].principal_id
  skip_service_principal_aad_check = true
}
