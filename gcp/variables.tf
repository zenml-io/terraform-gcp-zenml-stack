variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "name_suffix" {
  description = "Suffix to add to resource names"
  type        = string
}

variable "zenml_server_url" {
  description = "ZenML server URL"
  type        = string
}

variable "zenml_api_token" {
  description = "ZenML API token"
  type        = string
}