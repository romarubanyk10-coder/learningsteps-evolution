locals {
  vnet_cidr       = "10.20.0.0/16"
  aks_subnet_cidr = "10.20.0.0/22"
  db_subnet_cidr  = "10.20.8.0/24"
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [local.vnet_cidr]
  tags                = var.tags

  lifecycle {
    ignore_changes = [tags["created-on"]]
  }
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.aks_subnet_cidr]

  service_endpoint {
    service = "Microsoft.KeyVault"
  }
}

resource "azurerm_subnet" "db" {
  name                 = "snet-db"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.db_subnet_cidr]

  delegation {
    name = "postgresql-flexible"

    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }

  # Azure adds a Microsoft.Storage service endpoint to this subnet when the
  # first PostgreSQL server is created (for WAL backups). Terraform must not remove it.
  lifecycle {
    ignore_changes = [service_endpoint]
  }
}

resource "azurerm_network_security_group" "db" {
  name                = "nsg-snet-db"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  security_rule {
    name                       = "allow-postgres-from-aks"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = local.aks_subnet_cidr
    destination_address_prefix = local.db_subnet_cidr
  }

  security_rule {
    name                       = "allow-postgres-within-db-subnet"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = local.db_subnet_cidr
    destination_address_prefix = local.db_subnet_cidr
  }

  security_rule {
    name                       = "deny-other-vnet-inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  lifecycle {
    ignore_changes = [tags["created-on"]]
  }
}

resource "azurerm_subnet_network_security_group_association" "db" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.db.id
}

resource "azurerm_private_dns_zone" "postgres" {
  name                = "${var.project}.private.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  lifecycle {
    ignore_changes = [tags["created-on"]]
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                 = "link-${azurerm_virtual_network.main.name}"
  private_dns_zone_id  = azurerm_private_dns_zone.postgres.id
  virtual_network_id   = azurerm_virtual_network.main.id
  registration_enabled = false
  tags                 = var.tags

  lifecycle {
    ignore_changes = [tags["created-on"]]
  }
}
