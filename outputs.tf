output "gcs_service_connector" {
  description = "The GCS service connector that was registered with the ZenML server"
  value       = data.zenml_service_connector.gcs
}

output "gar_service_connector" {
  description = "The Google Artifact Registry service connector that was registered with the ZenML server"
  value       = data.zenml_service_connector.gar
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
  value       = data.zenml_stack_component.container_registry
}

output "orchestrator" {
  description = "The orchestrator that was registered with the ZenML server"
  value       = data.zenml_stack_component.orchestrator
}

output "step_operator" {
  description = "The step operator that was registered with the ZenML server"
  value       = data.zenml_stack_component.step_operator
}

output "image_builder" {
  description = "The image builder that was registered with the ZenML server"
  value       = data.zenml_stack_component.image_builder
}

output "experiment_tracker" {
  description = "The experiment tracker that was registered with the ZenML server"
  value       = local.is_version_gte_0_73 ? data.zenml_stack_component.experiment_tracker[0] : null
}

output "deployer" {
  description = "The deployer that was registered with the ZenML server"
  value       = local.use_cloud_run ? data.zenml_stack_component.deployer[0] : null
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
