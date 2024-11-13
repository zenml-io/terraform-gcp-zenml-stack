terraform {
    required_providers {
        google = {
            source  = "hashicorp/google"
        }
        zenml = {
            source = "zenml-io/zenml"
        }
    }
}

provider "google" {
    region  = "europe-west3"
    project = "zenml-core"
}

provider "zenml" {
    # server_url = <taken from the ZENML_SERVER_URL environment variable if not set here>
    # api_key = <taken from the ZENML_API_KEY environment variable if not set here>
}

module "zenml_stack" {
    source  = "../"

    orchestrator = "vertex" # or "skypilot", "airflow" or "local"
    zenml_pro_aws_account = "339712793861"
    zenml_stack_name = "gcp-stack"
}

output "zenml_stack_id" {
    value = module.zenml_stack.zenml_stack_id
    sensitive = true
}
output "zenml_stack_name" {
    value = module.zenml_stack.zenml_stack_name
    sensitive = true
}
output "gcs_service_connector" {
    value = module.zenml_stack.gcs_service_connector
    sensitive = true
}
output "gar_service_connector" {
    value = module.zenml_stack.gar_service_connector
    sensitive = true
}
output "gcp_service_connector" {
    value = module.zenml_stack.gcp_service_connector
    sensitive = true
}
output "artifact_store" {
    value = module.zenml_stack.artifact_store
    sensitive = true
}
output "container_registry" {
    value = module.zenml_stack.container_registry
    sensitive = true
}
output "orchestrator" {
    value = module.zenml_stack.orchestrator
    sensitive = true
}
output "step_operator" {
    value = module.zenml_stack.step_operator
    sensitive = true
}
output "image_builder" {
    value = module.zenml_stack.image_builder
    sensitive = true
}
output "zenml_stack" {
    value = module.zenml_stack.zenml_stack
}