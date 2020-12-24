# Creating the storage acount to house the container
resource "azurerm_storage_account" "bre_storageaccount" {
  name                     = "def${var.app_environment}eastusst001"
  resource_group_name      = azurerm_resource_group.bre_resourcegroup.name
  location                 = "East US"
  account_tier             = "Standard"
  account_replication_type = "GRS"

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }
}

# Creating the container to house the blob storage for css-data
resource "azurerm_storage_container" "bre_storagecontainer_css" {
  name                  = "css-data"
  storage_account_name  = azurerm_storage_account.bre_storageaccount.name
  container_access_type = "private"
}

# Creating the container to house the blob storage for debtor-docs
resource "azurerm_storage_container" "bre_storagecontainer_debtor" {
  name                  = "debtor-docs"
  storage_account_name  = azurerm_storage_account.bre_storageaccount.name
  container_access_type = "private"
}

# Creating the container to house the blob storage for e-signatures
resource "azurerm_storage_container" "bre_storagecontainer_esign" {
  name                  = "e-signatures"
  storage_account_name  = azurerm_storage_account.bre_storageaccount.name
  container_access_type = "private"
}

# Creating the container to house the blob storage for edi-data
resource "azurerm_storage_container" "bre_storagecontainer_edi" {
  name                  = "edi-for-consumption"
  storage_account_name  = azurerm_storage_account.bre_storageaccount.name
  container_access_type = "private"
}
