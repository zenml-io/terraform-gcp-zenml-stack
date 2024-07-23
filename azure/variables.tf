variable "location" {
  description = "The Azure region where resources will be created"
  # Make a choice from the list of Azure regions
  type        = string
  default     = "westus"

  validation {
    condition     = contains(["centralus", "eastus", "eastus2", "northcentralus", "southcentralus", "westcentralus", "westus", "westus2", "westus3"], var.location)
    error_message = "Skypilot currently only supports the US Azure regions" 
  }  
}

variable "zenml_server_url" {
  description = "The URL of the ZenML server"
  type        = string
}

variable "zenml_api_token" {
  description = "The API token for authenticating with the ZenML server"
  type        = string
  sensitive   = true
}

variable "storage_account_tier" {
  description = "The tier of the storage account"
  type        = string
  default     = "Standard"
}

variable "storage_account_replication_type" {
  description = "The replication type for the storage account"
  type        = string
  default     = "LRS"
}

variable "container_registry_sku" {
  description = "The SKU of the container registry"
  type        = string
  default     = "Basic"
}
