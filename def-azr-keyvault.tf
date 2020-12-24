data "azurerm_client_config" "current" {}

# Creates a Key Vault resource to store keys and secrets.
resource "azurerm_key_vault" "bre_kv" {
  name                        = "${var.app_environment}-eastus-kv-001"
  location                    = azurerm_resource_group.bre_resourcegroup.location
  resource_group_name         = azurerm_resource_group.bre_resourcegroup.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_enabled         = true
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"
}

resource "azurerm_key_vault_access_policy" "terraform_access_policy" {
  key_vault_id = azurerm_key_vault.bre_kv.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = data.azurerm_client_config.current.object_id

  certificate_permissions = [
    "backup", "create", "delete", "deleteissuers", "get", "getissuers",
    "import", "list", "listissuers", "managecontacts", "manageissuers",
    "purge", "recover", "restore", "setissuers", "update"
  ]

  key_permissions = [
    "get", "list", "create", "backup", "decrypt", "delete", "encrypt",
    "import", "purge", "recover", "restore", "sign", "unwrapKey",
    "update", "verify", "wrapKey"
  ]

  secret_permissions = [
    "get", "list", "set", "backup", "delete", "purge", "recover",
    "restore"
  ]

  storage_permissions = [
    "get", "backup", "delete", "deletesas", "getsas", "list", "listsas",
    "purge", "recover", "regeneratekey", "restore", "set", "setsas",
    "update"
  ]
}

resource "azurerm_key_vault_access_policy" "bre_kv_access_policy" {
  key_vault_id = azurerm_key_vault.bre_kv.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = azuread_service_principal.bre_app_sp.object_id

  key_permissions = [
    "get",
    "list",
    "update",
    "create",
    "decrypt",
    "encrypt",
    "sign",
    "verify",
  ]

  secret_permissions = [
    "get",
    "list",
    "set",
  ]

  storage_permissions = [
    "get",
  ]
}

# Creates a 2048-bit RSA Key Vault Key which is used to sign log in tokens for the app.
resource "azurerm_key_vault_key" "bre_token_signing_key" {
  name         = "bre-token-signing-key"
  key_vault_id = azurerm_key_vault.bre_kv.id
  key_type     = "RSA"
  key_size     = 2048

  # Sign and verify are the ones really needed.
  # But other supported values are "decrypt", "encrypt", "unwrapKey", and "wrapKey".
  key_opts = [
    "sign",
    "verify",
  ]

  # This needs to be explicitly set because Terraform will start creating the key
  # simultaneously with the access policy. This means that the access policy isn't
  # created when the key is starting to be created. So the permission to create
  # keys doesn't actually exist. And it'll error out. Unless this is specified,
  # in which case, Terraform will now wait till the access policy is fully created.
  depends_on = [
    azurerm_key_vault_access_policy.terraform_access_policy
  ]
}

# Creates the guest token for intra app container communication. Can be any random string.
resource "random_password" "bre_guest_token_secret_val" {
  length           = 64
  special          = true
  override_special = "_%@"
}

# Takes the token created above and puts it in a Key Vault secret.
# Populating this value can be done manually in order to prevent storing the secret in state.
# However we are going to go ahead and initialize this here. We can change this later if needed.
resource "azurerm_key_vault_secret" "bre_guest_token_secret" {
  name         = "${var.app_environment}-GUEST-TOKEN-SECRET"
  value        = random_password.bre_guest_token_secret_val.result
  key_vault_id = azurerm_key_vault.bre_kv.id

  # This needs to be explicitly set because Terraform will start creating the secret
  # simultaneously with the access policy. This means that the access policy isn't
  # created when the secret is starting to be created. So the permission to create
  # secrets doesn't actually exist. And it'll error out. Unless this is specified,
  # in which case, Terraform will now wait till the access policy is fully created.
  depends_on = [
    azurerm_key_vault_access_policy.terraform_access_policy
  ]
}

resource "azurerm_key_vault_secret" "postgres_admin_password" {
  name         = "ROOT-POSTGRES-ADMIN-PASSWORD"
  value        = random_password.bre_postgres_password.result
  key_vault_id = azurerm_key_vault.bre_kv.id

  # This needs to be explicitly set because Terraform will start creating the secret
  # simultaneously with the access policy. This means that the access policy isn't
  # created when the secret is starting to be created. So the permission to create
  # secrets doesn't actually exist. And it'll error out. Unless this is specified,
  # in which case, Terraform will now wait till the access policy is fully created.
  depends_on = [
    azurerm_key_vault_access_policy.terraform_access_policy
  ]
}


# Adds a topic to capture KeyVault events.
# We've to pipe events from here to Service bus.
resource "azurerm_eventgrid_system_topic" "bre_kv_change_event" {
  name                   = "${azurerm_key_vault.bre_kv.name}-vault-change-event"
  resource_group_name    = azurerm_resource_group.bre_resourcegroup.name
  location               = azurerm_resource_group.bre_resourcegroup.location
  source_arm_resource_id = azurerm_key_vault.bre_kv.id
  topic_type             = "Microsoft.KeyVault.vaults"
}

# Adds the above mentioned pipe so we can capture events from the topic and send it to our containers.
resource "azurerm_eventgrid_event_subscription" "bre_kv_change_event_sub" {
  name                          = "${azurerm_eventgrid_system_topic.bre_kv_change_event.name}-sub"
  scope                         = azurerm_resource_group.bre_resourcegroup.id
  service_bus_topic_endpoint_id = azurerm_servicebus_topic.bre_servicebustopic_vault_change.id
}
