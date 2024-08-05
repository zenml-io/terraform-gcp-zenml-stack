terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 1.19"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "http" "zenml_login" {
  count = var.zenml_api_key != "" ? 1 : 0
  url = "${var.zenml_server_url}/api/v1/login"

  method = "POST"

  request_body = "password=${urlencode(var.zenml_api_key)}"

  request_headers = {
    Content-Type = "application/x-www-form-urlencoded"
  }
}

provider "restapi" {
  alias                = "zenml_api"
  uri                  = var.zenml_server_url
  write_returns_object = true

  headers = {
    Authorization = "Bearer ${var.zenml_api_key == "" ? var.zenml_api_token : jsondecode(data.http.zenml_login[0].response_body).access_token}"
  }
}

data "google_project" "project" {
  # The project ID is auto-detected from the environment by default.
}

resource "random_id" "resource_name_suffix" {
  # This will generate a string of 12 characters, encoded as base64 which makes
  # it 8 characters long
  byte_length = 6
}

# Enable required APIs
resource "google_project_service" "iam" {
  service = "iam.googleapis.com"
  disable_on_destroy = false
}

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

resource "google_project_service" "cloudbuild" {
  service = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

resource "google_storage_bucket" "artifact_store" {
  name     = "zenml-${data.google_project.project.number}-${random_id.resource_name_suffix.hex}"
  location = var.region
  depends_on = [google_project_service.storage]
  force_destroy = true
}

resource "google_artifact_registry_repository" "container_registry" {
  location      = var.region
  repository_id = "zenml-${random_id.resource_name_suffix.hex}"
  format        = "DOCKER"
  depends_on    = [google_project_service.artifactregistry]
}

resource "google_service_account" "zenml_sa" {
  account_id   = "zenml-${random_id.resource_name_suffix.hex}"
  display_name = "ZenML Service Account"
}

# Update IAM roles for the service account
resource "google_project_iam_member" "storage_object_user" {
  project = var.project_id
  role    = "roles/storage.objectUser"
  member  = "serviceAccount:${google_service_account.zenml_sa.email}"

  condition {
    title       = "Restrict access to the ZenML bucket"
    description = "Grants access only to the ZenML bucket"
    expression  = "resource.name.startsWith('projects/_/buckets/${google_storage_bucket.artifact_store.name}')"
  }
}

resource "google_project_iam_member" "artifact_registry_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.createOnPushWriter"
  member  = "serviceAccount:${google_service_account.zenml_sa.email}"

  condition {
    title       = "Restrict access to the ZenML container registry"
    description = "Grants access only to the ZenML container registry"
    expression  = "resource.name.startsWith('projects/${data.google_project.project.number}/locations/${var.region}/repositories/${google_artifact_registry_repository.container_registry.repository_id}')"
  }
}

resource "google_project_iam_member" "ai_platform_service_agent" {
  project = var.project_id
  role    = "roles/aiplatform.serviceAgent"
  member  = "serviceAccount:${google_service_account.zenml_sa.email}"
}

resource "google_project_iam_member" "cloud_build_editor" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.editor"
  member  = "serviceAccount:${google_service_account.zenml_sa.email}"
}

resource "google_service_account_key" "zenml_sa_key" {
  service_account_id = google_service_account.zenml_sa.name
}


resource "restapi_object" "zenml_stack" {
  provider = restapi.zenml_api
  path = "/api/v1/stacks"
  create_path = "/api/v1/workspaces/default/full-stack"
  data = <<EOF
{
  "name": "${var.zenml_stack_name == "" ? "terraform-gcp-${random_id.resource_name_suffix.hex}" : var.zenml_stack_name}",
  "description": "Deployed with the ZenML GCP Stack Terraform module in the '${var.project_id}' project and '${var.region}' region.",
  "labels": {
    "zenml:provider": "gcp",
    "zenml:deployment": "${var.zenml_stack_deployment}"
  },
  "service_connectors": [
    {
      "type": "gcp",
      "auth_method": "service-account",
      "configuration": {
        "service_account_json": "${google_service_account_key.zenml_sa_key.private_key}"
      }
    }
  ],
  "components": {
    "artifact_store": {
      "flavor": "gcp",
      "service_connector_index": 0,
      "configuration": {
        "path": "gs://${google_storage_bucket.artifact_store.name}"
      }
    },
    "container_registry":{
      "flavor": "gcp",
      "service_connector_index": 0,
      "configuration": {
        "uri": "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.container_registry.repository_id}"
      }
    },
    "orchestrator": {
      "flavor": "vertex",
      "service_connector_index": 0,
      "configuration": {
        "location": "${var.region}",
        "workload_service_account": "${google_service_account.zenml_sa.email}"
      }
    },
    "image_builder": {
      "flavor": "gcp",
      "service_connector_index": 0
    }
  }
}
EOF
  lifecycle {
    # Given that we don't yet support updating a full stack, we force a new
    # resource to be created whenever any of the inputs change.
    replace_triggered_by = [
      random_id.resource_name_suffix,
      google_storage_bucket.artifact_store,
      google_artifact_registry_repository.container_registry,
      google_service_account.zenml_sa,
      google_service_account_key.zenml_sa_key
    ]
  }

  # Depends on all other resources
  depends_on = [
    google_project_service.iam,
    google_project_service.artifactregistry,
    google_project_service.storage,
    google_project_service.aiplatform,
    google_project_service.cloudbuild,
    google_storage_bucket.artifact_store,
    google_artifact_registry_repository.container_registry,
    google_service_account.zenml_sa,
    google_project_iam_member.storage_object_user,
    google_project_iam_member.artifact_registry_writer,
    google_project_iam_member.ai_platform_service_agent,
    google_project_iam_member.cloud_build_editor,
    google_service_account_key.zenml_sa_key
  ]
}
