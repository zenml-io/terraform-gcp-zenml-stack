output "gcs_service_connector" {
  description = "The GCS service connector that was registered with the ZenML server"
  value       = data.zenml_service_connector.gcs
}

output "gar_service_connector" {
  description = "The Google Artifact Registry service connector that was registered with the ZenML server"
  value       = var.enable_container_registry ? data.zenml_service_connector.gar[0] : null
}

output "gcp_service_connector" {
  description = "The generic GCP service connector that was registered with the ZenML server"
  value       = data.zenml_service_connector.gcp
}

output "artifact_store" {
  description = "The artifact store that was registered with the ZenML server"
  value       = data.zenml_stack_component.artifact_store
}

output "container_registry" {
  description = "The container registry that was registered with the ZenML server"
  value       = var.enable_container_registry ? data.zenml_stack_component.container_registry[0] : null
}

output "orchestrator" {
  description = "The orchestrator that was registered with the ZenML server"
  value       = data.zenml_stack_component.orchestrator
}

output "step_operator" {
  description = "The step operator that was registered with the ZenML server"
  value       = var.enable_step_operator ? data.zenml_stack_component.step_operator[0] : null
}

output "image_builder" {
  description = "The image builder that was registered with the ZenML server"
  value       = var.enable_image_builder ? data.zenml_stack_component.image_builder[0] : null
}

output "experiment_tracker" {
  description = "The experiment tracker that was registered with the ZenML server"
  value       = var.enable_experiment_tracker && local.use_experiment_tracker ? data.zenml_stack_component.experiment_tracker[0] : null
}

output "deployer" {
  description = "The deployer that was registered with the ZenML server"
  value       = var.enable_deployer && local.use_deployer ? data.zenml_stack_component.deployer[0] : null
}

output "zenml_stack" {
  description = "The ZenML stack that was registered with the ZenML server"
  value       = data.zenml_stack.stack
}

output "zenml_stack_id" {
  description = "The ID of the ZenML stack that was registered with the ZenML server"
  value       = zenml_stack.stack.id
}

output "zenml_stack_name" {
  description = "The name of the ZenML stack that was registered with the ZenML server"
  value       = zenml_stack.stack.name
}
