# Provider for creating Azure resources.
provider "azurerm" {
  # Whilst version is optional, we /strongly recommend/ using it to pin the version of the Provider being used
  version         = "=2.39.0"
  subscription_id = var.azure_subscription_id
  features {}
}

# Provider for managing authentication and service principals
provider "azuread" {
  version = "1.1.1"
}

terraform {
  backend "azurerm" {
    resource_group_name  = "prod-eastus-rg-aks-001"
    storage_account_name = "defprodeastusst001"
    container_name       = "terraform-data"
  }
}

# Create a randomness seed
resource "random_id" "server" {
  keepers = {
    ami_id = 1
  }

  byte_length = 8
}

# Creating the resource group to house all of the AKS resources
resource "azurerm_resource_group" "bre_resourcegroup" {
  name     = "${var.app_environment}-eastus-rg-aks-001"
  location = "East us"
  tags = {
    type         = "development"
    application  = "kubernetes"
    businessunit = "collections"
    payment      = "invoice"
  }
}

data "azurerm_resource_group" "subnet_resourcegroup" {
  name = "prod-eastus-rg-aks-001"
}

# Create an application
resource "azuread_application" "bre_app" {
  name = "${var.app_environment}-${var.app_name}"
}

# Create a service principal
resource "azuread_service_principal" "bre_app_sp" {
  application_id = azuread_application.bre_app.application_id
}

resource "random_password" "bre_app_sp_password_gen" {
  length  = 32
  special = true
}

resource "azuread_service_principal_password" "bre_app_sp_password" {
  service_principal_id = azuread_service_principal.bre_app_sp.id
  description          = "BRE App Password"
  value                = random_password.bre_app_sp_password_gen.result
  end_date_relative    = "8760h"
}
