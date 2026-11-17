terraform {
  backend "azurerm" {
    resource_group_name  = "rg-learningsteps-tfstate"
    storage_account_name = "stlstfstatedf9835"
    container_name       = "tfstate"
    key                  = "learningsteps-evolution.tfstate"
    use_azuread_auth     = true
  }
}