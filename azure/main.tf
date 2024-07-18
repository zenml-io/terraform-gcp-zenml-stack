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
  }
}

provider "azurerm" {
  features {}
}

provider "azuread" {}

# Enable required services
resource "azurerm_resource_group" "zenml_rg" {
  name     = "zenml-rg-${var.name_suffix}"
  location = var.location
}

resource "azurerm_storage_account" "artifact_store" {
  name                     = "zenmlartifacts${lower(replace(var.name_suffix, "-", ""))}"
  resource_group_name      = azurerm_resource_group.zenml_rg.name
  location                 = azurerm_resource_group.zenml_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "artifact_container" {
  name                  = "zenml-artifacts"
  storage_account_name  = azurerm_storage_account.artifact_store.name
  container_access_type = "private"
}

resource "azurerm_container_registry" "zenml_acr" {
  name                = "zenmlacr${lower(replace(var.name_suffix, "-", ""))}"
  resource_group_name = azurerm_resource_group.zenml_rg.name
  location            = azurerm_resource_group.zenml_rg.location
  sku                 = "Standard"
  admin_enabled       = true
}

resource "azuread_application" "zenml_sp" {
  display_name = "zenml-sp-${var.name_suffix}"
}

resource "azuread_service_principal" "zenml_sp" {
  application_id = azuread_application.zenml_sp.application_id
}

resource "azuread_service_principal_password" "zenml_sp_password" {
  service_principal_id = azuread_service_principal.zenml_sp.id
}

# Assign roles to the Service Principal
resource "azurerm_role_assignment" "zenml_sp_contributor" {
  scope                = azurerm_resource_group.zenml_rg.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.zenml_sp.object_id
}

resource "azurerm_role_assignment" "zenml_sp_storage_blob_data_contributor" {
  scope                = azurerm_storage_account.artifact_store.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.zenml_sp.object_id
}

resource "azurerm_role_assignment" "zenml_sp_acr_push" {
  scope                = azurerm_container_registry.zenml_acr.id
  role_definition_name = "AcrPush"
  principal_id         = azuread_service_principal.zenml_sp.object_id
}

resource "null_resource" "zenml_stack" {
  depends_on = [
    azurerm_storage_account.artifact_store,
    azurerm_container_registry.zenml_acr,
    azuread_service_principal.zenml_sp,
    azurerm_role_assignment.zenml_sp_contributor,
    azurerm_role_assignment.zenml_sp_storage_blob_data_contributor,
    azurerm_role_assignment.zenml_sp_acr_push,
    azuread_service_principal_password.zenml_sp_password
  ]

  provisioner "local-exec" {
    command = <<-EOT
      {
        # Create a trap to ensure the temporary file is deleted even if the script exits prematurely
        trap 'rm -f /tmp/sp_creds.json' EXIT

        zenml integration install azure -y
        zenml connect --url=${var.zenml_server_url} --api-key=${var.zenml_api_token}
        
        # Create service principal credentials file
        echo "Creating service principal credentials file..."
        echo '{
          "appId": "${azuread_application.zenml_sp.application_id}",
          "password": "${azuread_service_principal_password.zenml_sp_password.value}",
          "tenant": "${data.azurerm_client_config.current.tenant_id}"
        }' > /tmp/sp_creds.json
        echo "Service principal credentials file created at /tmp/sp_creds.json"
        
        # Check if the file is empty or not
        if [ ! -s /tmp/sp_creds.json ]; then
          echo "Error: /tmp/sp_creds.json is empty. Service principal credentials creation failed."
          exit 1
        fi

        echo "Registering Azure Service Connector..."
        zenml service-connector register azure-connector-${var.name_suffix} \
          --type azure \
          --auth-method service-principal \
          --service_principal_json="@/tmp/sp_creds.json"

        # Register and connect Azure Container Registry
        zenml container-registry register acr-${var.name_suffix} \
          --flavor=azure \
          --uri=${azurerm_container_registry.zenml_acr.login_server}
        zenml container-registry connect acr-${var.name_suffix} --connector azure-connector-${var.name_suffix} --no-verify

        # Register other stack components
        zenml artifact-store register azure-store-${var.name_suffix} --flavor=azure --path=az://${azurerm_storage_container.artifact_container.name}
        zenml artifact-store connect azure-store-${var.name_suffix} --connector azure-connector-${var.name_suffix}

        zenml orchestrator register azure-vm-${var.name_suffix} --flavor=vm_azure --project=${var.project_id} --location=${var.location}
        zenml orchestrator connect azure-vm-${var.name_suffix} --connector azure-connector-${var.name_suffix}

        # Register and set the stack
        zenml stack register azure-stack-${var.name_suffix} \
          -a azure-store-${var.name_suffix} \
          -c acr-${var.name_suffix} \
          -o azure-vm-${var.name_suffix} \
          --set

        # Clean up the temporary service principal credentials file
        echo "Cleaning up temporary service principal credentials file..."
        rm -f /tmp/sp_creds.json
        
      } >> zenml_stack_setup.log 2>&1
      
      if [ $? -ne 0 ]; then
        echo "An error occurred during ZenML stack setup. Check zenml_stack_setup.log for details."
        cat zenml_stack_setup.log
        exit 1
      fi
    EOT
  }
}

resource "null_resource" "zenml_stack_cleanup" {
  depends_on = [null_resource.zenml_stack]

  triggers = {
    zenml_server_url = var.zenml_server_url
    zenml_api_token = var.zenml_api_token
    name_suffix = var.name_suffix
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      {
        set -e
        zenml connect --url=${self.triggers.zenml_server_url} --api-key=${self.triggers.zenml_api_token}
        
        # Delete stack components
        zenml stack set default || true
        zenml stack delete azure-stack-${self.triggers.name_suffix} -y || echo "Failed to delete stack, it may not exist"
        zenml artifact-store delete azure-store-${self.triggers.name_suffix} || echo "Failed to delete artifact store, it may not exist"
        zenml container-registry delete acr-${self.triggers.name_suffix} || echo "Failed to delete container registry, it may not exist"
        zenml orchestrator delete azure-vm-${self.triggers.name_suffix} || echo "Failed to delete orchestrator, it may not exist"
        zenml service-connector delete azure-connector-${self.triggers.name_suffix} || echo "Failed to delete service connector, it may not exist"
      } >> zenml_stack_cleanup.log 2>&1
      
      if [ $? -ne 0 ]; then
        echo "An error occurred during ZenML stack cleanup. Check zenml_stack_cleanup.log for details."
        exit 1
      fi
    EOT
  }
}