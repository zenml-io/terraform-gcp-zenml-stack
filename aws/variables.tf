variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "eu-central-1"
}

variable "zenml_server_url" {
  description = "The URL of the ZenML server"
  type        = string
}

variable "zenml_api_key" {
  description = "ZenML API key to authenticate with the ZenML server"
  type        = string
  sensitive   = true
  default     = ""
}

variable "zenml_api_token" {
  description = "The API token for authenticating with the ZenML server"
  type        = string
  sensitive   = true
  default     = ""
}
