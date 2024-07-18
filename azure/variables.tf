variable "name_suffix" {
  description = "A suffix to append to the names of resources to ensure uniqueness"
  type        = string
}

variable "location" {
  description = "The Azure region where resources will be created"
  type        = string
  default     = "eastus"
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

variable "project_id" {
  description = "The Azure subscription ID where resources will be created"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group to create"
  type        = string
  default     = "zenml-resources"
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
  default     = "Standard"
}

variable "service_principal_name" {
  description = "The name of the service principal to create"
  type        = string
  default     = "zenml-service-principal"
}