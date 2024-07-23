variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "europe-west3"
}

variable "zenml_server_url" {
  description = "ZenML server URL"
  type        = string
}

variable "zenml_api_key" {
  description = "ZenML API key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "zenml_api_token" {
  description = "ZenML API token"
  type        = string
  sensitive   = true
  default     = ""
}