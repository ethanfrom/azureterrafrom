# Configure the provider
provider "azurerm" {
    version = "=1.31.0"
}

# Create a new resource group
resource "azurerm_resource_group" "rg" {
    name     = "myTFResourceGroup"
    location = "eastus"
}
