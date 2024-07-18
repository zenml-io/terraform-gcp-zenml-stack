variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "name_suffix" {
  description = "A suffix to append to resource names for uniqueness"
  type        = string
  default     = "default"
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
  description = "The AWS account ID"
  type        = string
}