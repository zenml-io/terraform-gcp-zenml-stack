variable "orchestrator" {
  description = "The orchestrator to be used, either 'vertex', 'skypilot', 'airflow' or 'local'"
  type        = string
  default     = "vertex"

  validation {
    condition     = contains(["vertex", "skypilot", "airflow", "local"], var.orchestrator)
    error_message = "The orchestrator must be either 'vertex', 'skypilot', 'airflow' or 'local'"
  }
}

variable "zenml_stack_name" {
  description = "A custom name for the ZenML stack that will be registered with the ZenML server"
  type        = string
  default     = ""
}

variable "zenml_stack_deployment" {
  description = "The deployment type for the ZenML stack. Used as a label for the registered ZenML stack."
  type        = string
  default     = "terraform"
}

variable "zenml_pro_aws_account" {
  description = "The AWS account ID in the context of which the ZenML Pro tenant is running. This is only used with ZenML Pro users to configure GCP workload identity provider for the ZenML stack authentication."
  type        = string
  default     = "715803424590"
}
