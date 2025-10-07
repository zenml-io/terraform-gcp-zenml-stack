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

variable "enable_step_operator" {
  description = "Whether to include the step operator in the stack"
  type        = bool
  default     = true
}

variable "step_operator_config" {
  description = "Additional configuration for the step operator"
  type        = map(string)
  default     = {}
}

variable "enable_container_registry" {
  description = "Whether to include the container registry in the stack"
  type        = bool
  default     = true
}

variable "container_registry_config" {
  description = "Additional configuration for the container registry"
  type        = map(string)
  default     = {}
}

variable "enable_image_builder" {
  description = "Whether to include the image builder in the stack"
  type        = bool
  default     = true
}

variable "image_builder_config" {
  description = "Additional configuration for the image builder"
  type        = map(string)
  default     = {}
}

variable "enable_experiment_tracker" {
  description = "Whether to include the experiment tracker in the stack"
  type        = bool
  default     = true
}

variable "experiment_tracker_config" {
  description = "Additional configuration for the experiment tracker"
  type        = map(string)
  default     = {}
}

variable "enable_deployer" {
  description = "Whether to include the deployer in the stack"
  type        = bool
  default     = true
}

variable "deployer_config" {
  description = "Additional configuration for the deployer"
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

variable "labels" {
  type        = map(string)
  description = "A map of labels to apply to all GCP resources created by this module."
  default     = {}
}

variable "region" {
  type        = string
  description = "The GCP region to deploy resources in. If not set, the provider's region will be used."
  default     = null
}

variable "project_id" {
  type        = string
  description = "The GCP project ID to deploy resources in. If not set, the provider's project ID will be used."
  default     = null
}
