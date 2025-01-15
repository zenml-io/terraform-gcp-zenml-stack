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
