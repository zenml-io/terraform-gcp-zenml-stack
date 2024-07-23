terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 1.19"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azuread" {}

data "http" "zenml_login" {
  count = var.zenml_api_key != "" ? 1 : 0
  url = "${var.zenml_server_url}/api/v1/login"

  method = "POST"

  request_body = "password=${urlencode(var.zenml_api_key)}"

  request_headers = {
    Content-Type = "application/x-www-form-urlencoded"
  }
}

provider "restapi" {
  alias                = "zenml_api"
  uri                  = var.zenml_server_url
  write_returns_object = true

  headers = {
    Authorization = "Bearer ${var.zenml_api_key == "" ? var.zenml_api_token : jsondecode(data.http.zenml_login[0].response_body).access_token}"
  }
}

data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}
# Get current subscription details
data "azurerm_subscription" "primary" {
  # This will get the subscription ID from the provider configuration
}

resource "random_id" "resource_name_suffix" {
  # This will generate a string of 12 characters, encoded as base64 which makes
  # it 8 characters long
  byte_length = 6
}

resource "azurerm_resource_group" "resource_group" {
  name     = "zenml-${random_id.resource_name_suffix.hex}"
  location = var.location
}

resource "azurerm_storage_account" "artifact_store" {
  name                     = "zenml${random_id.resource_name_suffix.hex}"
  resource_group_name      = azurerm_resource_group.resource_group.name
  location                 = azurerm_resource_group.resource_group.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication_type
}

resource "azurerm_storage_container" "artifact_container" {
  name                  = "zenml${random_id.resource_name_suffix.hex}"
  storage_account_name  = azurerm_storage_account.artifact_store.name
  container_access_type = "private"
}

resource "azurerm_container_registry" "container_registry" {
  name                = "zenml${random_id.resource_name_suffix.hex}"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  sku                 = var.container_registry_sku
  admin_enabled       = true
}

resource "azuread_application" "service_principal_app" {
  display_name = "zenml-${random_id.resource_name_suffix.hex}"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "service_principal" {
  client_id = azuread_application.service_principal_app.client_id
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal_password" "service_principal_password" {
  service_principal_id = azuread_service_principal.service_principal.object_id
}

# Assign roles to the Service Principal

resource "azurerm_role_assignment" "storage_blob_data_contributor_role" {
  scope                = azurerm_storage_account.artifact_store.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.service_principal.object_id
}

resource "azurerm_role_assignment" "acr_push_role" {
  scope                = azurerm_container_registry.container_registry.id
  role_definition_name = "AcrPush"
  principal_id         = azuread_service_principal.service_principal.object_id
}

resource "azurerm_role_assignment" "acr_pull_role" {
  scope                = azurerm_container_registry.container_registry.id
  role_definition_name = "AcrPull"
  principal_id         = azuread_service_principal.service_principal.object_id
}

resource "azurerm_role_assignment" "acr_contributor_role" {
  scope                = azurerm_container_registry.container_registry.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.service_principal.object_id
}

# This very permissive role is required only by Skypilot. Unfortunately, there
# is no way to reduce the scope of this role to a specific resource group yet
# (see https://github.com/skypilot-org/skypilot/issues/2962).
resource "azurerm_role_assignment" "subscription_contributor_role" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Owner"
  principal_id         = azuread_service_principal.service_principal.object_id
}

resource "restapi_object" "zenml_stack" {
  provider = restapi.zenml_api
  path = "/api/v1/stacks"
  create_path = "/api/v1/workspaces/default/full-stack"
  data = <<EOF
{
  "name": "terraform-azure-stack-${random_id.resource_name_suffix.hex}",
  "description": "Deployed with the ZenML Azure Stack Terraform module in the '${data.azurerm_client_config.current.subscription_id}' subscription, '${azurerm_resource_group.resource_group.name}' resource group and '${azurerm_resource_group.resource_group.location}' region.",
  "labels": {
    "zenml:provider": "azure",
    "zenml:deployment": "terraform"
  },
  "service_connectors": [
    {
      "type": "azure",
      "auth_method": "service-principal",
      "configuration": {
        "subscription_id": "${data.azurerm_client_config.current.subscription_id}",
        "resource_group": "${azurerm_resource_group.resource_group.name}",
        "storage_account": "${azurerm_storage_account.artifact_store.name}",
        "tenant_id": "${data.azurerm_client_config.current.tenant_id}",
        "client_id": "${azuread_application.service_principal_app.client_id}",
        "client_secret": "${azuread_service_principal_password.service_principal_password.value}"
      }
    }
  ],
  "components": {
    "artifact_store": {
      "flavor": "azure",
      "service_connector_index": 0,
      "configuration": {
        "path": "az://${azurerm_storage_container.artifact_container.name}"
      }
    },
    "container_registry":{
      "flavor": "azure",
      "service_connector_index": 0,
      "configuration": {
        "uri": "${azurerm_container_registry.container_registry.login_server}"
      }
    },
    "orchestrator": {
      "flavor": "vm_azure",
      "service_connector_index": 0,
      "configuration": {
        "region": "${azurerm_resource_group.resource_group.location}"
      }
    },
    "image_builder": {
      "flavor": "local"
    }
  }
}
EOF
  lifecycle {
    # Given that we don't yet support updating a full stack, we force a new
    # resource to be created whenever any of the inputs change.
    replace_triggered_by = [
      random_id.resource_name_suffix,
      azurerm_resource_group.resource_group,
      azurerm_storage_account.artifact_store,
      azurerm_storage_container.artifact_container,
      azurerm_container_registry.container_registry,
      azuread_application.service_principal_app,
      azuread_service_principal.service_principal,
      azuread_service_principal_password.service_principal_password
    ]
  }
}
