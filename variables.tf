variable "orchestrator" {
  description = "The orchestrator to be used, either 'vertex', 'skypilot', 'airflow' or 'local'"
  type        = string
  default     = "vertex"

  validation {
    condition     = contains(["vertex", "skypilot", "airflow", "local"], var.orchestrator)
    error_message = "The orchestrator must be either 'vertex', 'skypilot', 'airflow' or 'local'"
  }
}

variable "artifact_store_config" {
  description = "Additional configuration for the artifact store"
  type        = map(string)
  default     = {}
}

variable "orchestrator_config" {
  description = "Additional configuration for the orchestrator"
  type        = map(string)
  default     = {}
}

variable "step_operator_config" {
  description = "Additional configuration for the step operator"
  type        = map(string)
  default     = {}
}

variable "container_registry_config" {
  description = "Additional configuration for the container registry"
  type        = map(string)
  default     = {}
}

variable "image_builder_config" {
  description = "Additional configuration for the image builder"
  type        = map(string)
  default     = {}
}

variable "experiment_tracker_config" {
  description = "Additional configuration for the experiment tracker"
  type        = map(string)
  default     = {}
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
