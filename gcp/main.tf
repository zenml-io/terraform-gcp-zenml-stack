terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "artifactregistry" {
  service = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "storage" {
  service = "storage-api.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "aiplatform" {
  service = "aiplatform.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudfunctions" {
  service = "cloudfunctions.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudrun" {
  service = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "container" {
  service = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudbuild" {
  service = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "logging" {
  service = "logging.googleapis.com"
  disable_on_destroy = false
}

resource "google_storage_bucket" "artifact_store" {
  name     = "zenml-artifact-store-${var.name_suffix}"
  location = var.region
  depends_on = [google_project_service.storage]
}

resource "google_artifact_registry_repository" "container_registry" {
  location      = var.region
  repository_id = "zenml-container-registry-${var.name_suffix}"
  format        = "DOCKER"
  depends_on    = [google_project_service.artifactregistry]
}

resource "google_service_account" "zenml_sa" {
  account_id   = "zenml-sa-${lower(replace(var.name_suffix, "_", "-"))}"
  display_name = "ZenML Service Account"
}

# Update IAM roles for the service account
resource "google_project_iam_member" "storage_object_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.zenml_sa.email}"
}

resource "google_project_iam_member" "ai_platform_service_agent" {
  project = var.project_id
  role    = "roles/aiplatform.serviceAgent"
  member  = "serviceAccount:${google_service_account.zenml_sa.email}"
}

resource "google_project_iam_member" "artifact_registry_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.zenml_sa.email}"
}

resource "google_project_iam_member" "artifact_registry_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.zenml_sa.email}"
}

resource "google_project_iam_member" "kubernetes_engine_viewer" {
  project = var.project_id
  role    = "roles/container.viewer"
  member  = "serviceAccount:${google_service_account.zenml_sa.email}"
}

resource "google_service_account_key" "zenml_sa_key" {
  service_account_id = google_service_account.zenml_sa.name
}

resource "null_resource" "zenml_stack" {
  depends_on = [
    google_storage_bucket.artifact_store,
    google_artifact_registry_repository.container_registry,
    google_service_account.zenml_sa,
    google_project_iam_member.storage_object_admin,
    google_project_iam_member.ai_platform_service_agent,
    google_project_iam_member.artifact_registry_writer,
    google_service_account_key.zenml_sa_key,
    google_project_service.cloudfunctions,
    google_project_service.cloudrun,
    google_project_service.cloudbuild,
    google_project_service.logging,
    google_project_iam_member.artifact_registry_reader,
    google_project_iam_member.kubernetes_engine_viewer,
    google_project_service.container
  ]

  provisioner "local-exec" {
    command = <<-EOT
      {
        # Create a trap to ensure the temporary file is deleted even if the script exits prematurely
        trap 'rm -f /tmp/sa_key.json' EXIT

        zenml integration install gcp -y
        zenml connect --url=${var.zenml_server_url} --api-key=${var.zenml_api_token}
        
        # Register GCP Service Connector
        echo "Creating service account key file..."
        echo '${google_service_account_key.zenml_sa_key.private_key}' | base64 --decode > /tmp/sa_key.json
        echo "Service account key file created at /tmp/sa_key.json"
        
        # Check if the file is empty or not
        if [ ! -s /tmp/sa_key.json ]; then
          echo "Error: /tmp/sa_key.json is empty. Service account key decoding failed."
          exit 1
        fi

        echo "Registering GCP Service Connector..."
        zenml service-connector register gcp-connector-${var.name_suffix} \
          --type gcp \
          --auth-method service-account \
          --service_account_json="@/tmp/sa_key.json"

        # Register and connect GCP Container Registry
        zenml container-registry register gcr-${var.name_suffix} \
          --flavor=gcp \
          --uri=${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.container_registry.repository_id}
        zenml container-registry connect gcr-${var.name_suffix} --connector gcp-connector-${var.name_suffix} --no-verify

        # Register other stack components
        zenml artifact-store register gcs-${var.name_suffix} --flavor=gcp --path=gs://${google_storage_bucket.artifact_store.name}
        zenml artifact-store connect gcs-${var.name_suffix} --connector gcp-connector-${var.name_suffix}

        zenml orchestrator register vertex-${var.name_suffix} --flavor=vertex --project=${var.project_id} --location=${var.region}
        zenml orchestrator connect vertex-${var.name_suffix} --connector gcp-connector-${var.name_suffix}

        # Register and set the stack
        zenml stack register gcp-stack-${var.name_suffix} \
          -a gcs-${var.name_suffix} \
          -c gcr-${var.name_suffix} \
          -o vertex-${var.name_suffix} \
          --set

        # Clean up the temporary service account key file
        echo "Cleaning up temporary service account key file..."
        rm -f /tmp/sa_key.json
        
      } >> zenml_stack_setup.log 2>&1
      
      if [ $? -ne 0 ]; then
        echo "An error occurred during ZenML stack setup. Check zenml_stack_setup.log for details."
        cat zenml_stack_setup.log
        exit 1
      fi
    EOT
  }
}

resource "null_resource" "zenml_stack_cleanup" {
  depends_on = [null_resource.zenml_stack]

  triggers = {
    zenml_server_url = var.zenml_server_url
    zenml_api_token = var.zenml_api_token
    name_suffix = var.name_suffix
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      {
        set -e
        zenml connect --url=${self.triggers.zenml_server_url} --api-key=${self.triggers.zenml_api_token}
        
        # Delete stack components
        zenml stack set default || true
        zenml stack delete gcp-stack-${self.triggers.name_suffix} -y || echo "Failed to delete stack, it may not exist"
        zenml artifact-store delete gcs-${self.triggers.name_suffix} || echo "Failed to delete artifact store, it may not exist"
        zenml container-registry delete gcr-${self.triggers.name_suffix} || echo "Failed to delete container registry, it may not exist"
        zenml orchestrator delete vertex-${self.triggers.name_suffix} || echo "Failed to delete orchestrator, it may not exist"
        zenml service-connector delete gcp-connector-${self.triggers.name_suffix} || echo "Failed to delete service connector, it may not exist"
      } >> zenml_stack_cleanup.log 2>&1
      
      if [ $? -ne 0 ]; then
        echo "An error occurred during ZenML stack cleanup. Check zenml_stack_cleanup.log for details."
        exit 1
      fi
    EOT
  }
}