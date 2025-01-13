terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    zenml = {
        source = "zenml-io/zenml"
    }
  }
}

data "google_client_config" "current" {}
data "google_project" "project" {
  project_id = data.google_client_config.current.project
}
data "zenml_server" "zenml_info" {}

locals {
  zenml_pro_tenant_id = try(data.zenml_server.zenml_info.metadata["tenant_id"], null)
  dashboard_url = try(data.zenml_server.zenml_info.dashboard_url, "")
  # Check if the dashboard URL indicates a ZenML Cloud deployment
  is_zenml_cloud = length(regexall("^https://(staging\\.)?cloud\\.zenml\\.io/", local.dashboard_url)) > 0
  zenml_version = data.zenml_server.zenml_info.version
  zenml_pro_tenant_iam_role_name = local.zenml_pro_tenant_id != null ? "zenml-${local.zenml_pro_tenant_id}" : ""
  # Use workload identity federation only when connected to a ZenML Pro tenant running version higher than 0.63.0 and
  # not using SkyPilot. SkyPilot cannot be used with workload identity federation because it does not support the GCP
  # temporary credentials generated by ZenML from the workload identity pool. ZenML higher than 0.63.0 is required
  # because the GCP workload identity federation feature was not available as a GCP Service Connector feature before
  # that version.
  use_workload_identity = local.is_zenml_cloud && var.orchestrator != "skypilot" && (local.zenml_version != null && split(".", local.zenml_version)[1] > 63)
}

resource "random_id" "resource_name_suffix" {
  # This will generate a string of 12 characters, encoded as base64 which makes
  # it 8 characters long
  byte_length = 6
}

# Enable required APIs
resource "google_project_service" "common_services" {
  for_each = toset([
    "iam.googleapis.com",
    "artifactregistry.googleapis.com",
    "storage-api.googleapis.com",
    "cloudbuild.googleapis.com",
    "aiplatform.googleapis.com",
  ])
  service = each.key
  disable_on_destroy = false
}

resource "google_project_service" "composer" {
  count = var.orchestrator == "airflow" ? 1 : 0
  service = "composer.googleapis.com"
  disable_on_destroy = false
}

resource "google_storage_bucket" "artifact_store" {
  name     = "zenml-${data.google_project.project.number}-${random_id.resource_name_suffix.hex}"
  location = data.google_client_config.current.region
  depends_on = [google_project_service.common_services]
  force_destroy = true
}

resource "google_artifact_registry_repository" "container_registry" {
  location      = data.google_client_config.current.region
  repository_id = "zenml-${random_id.resource_name_suffix.hex}"
  format        = "DOCKER"
  depends_on    = [google_project_service.common_services]
}

resource "google_composer_environment" "composer_env" {
  count  = var.orchestrator == "airflow" ? 1 : 0
  name   = "zenml-${random_id.resource_name_suffix.hex}"
  region = data.google_client_config.current.region

  storage_config {
    bucket = google_storage_bucket.artifact_store.name
  }

  config {
    environment_size = "ENVIRONMENT_SIZE_SMALL"
    resilience_mode  = "STANDARD_RESILIENCE"
  }
}

resource "google_service_account" "zenml_sa" {
  account_id   = "zenml-${random_id.resource_name_suffix.hex}"
  display_name = "ZenML Service Account"
}

# Update IAM roles for the service account
resource "google_project_iam_member" "storage_object_user" {
  project = data.google_client_config.current.project
  role    = "roles/storage.objectUser"
  member  = "serviceAccount:${google_service_account.zenml_sa.email}"

  condition {
    title       = "Restrict access to the ZenML bucket"
    description = "Grants access only to the ZenML bucket"
    expression  = "resource.name.startsWith('projects/_/buckets/${google_storage_bucket.artifact_store.name}')"
  }
}

resource "google_project_iam_member" "artifact_registry_writer" {
  project = data.google_client_config.current.project
  role    = "roles/artifactregistry.createOnPushWriter"
  member  = "serviceAccount:${google_service_account.zenml_sa.email}"

  condition {
    title       = "Restrict access to the ZenML container registry"
    description = "Grants access only to the ZenML container registry"
    expression  = "resource.name.startsWith('projects/${data.google_project.project.number}/locations/${data.google_client_config.current.region}/repositories/${google_artifact_registry_repository.container_registry.repository_id}')"
  }
}

resource "google_project_iam_member" "cloud_build_editor" {
  project = data.google_client_config.current.project
  role    = "roles/cloudbuild.builds.editor"
  member  = "serviceAccount:${google_service_account.zenml_sa.email}"
}

resource "google_project_iam_member" "cloud_build_builder" {
  project = data.google_client_config.current.project
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${google_service_account.zenml_sa.email}"
}

resource "google_project_iam_member" "ai_platform_service_agent" {
  project = data.google_client_config.current.project
  role    = "roles/aiplatform.serviceAgent"
  member  = "serviceAccount:${google_service_account.zenml_sa.email}"
}

resource "google_project_iam_member" "skypilot_browser" {
  count   = var.orchestrator == "skypilot" ? 1 : 0
  project = data.google_client_config.current.project
  role    = "roles/browser"
  member  = "serviceAccount:${google_service_account.zenml_sa.email}"
}

resource "google_project_iam_member" "skypilot_compute_admin" {
  count   = var.orchestrator == "skypilot" ? 1 : 0
  project = data.google_client_config.current.project
  role    = "roles/compute.admin"
  member  = "serviceAccount:${google_service_account.zenml_sa.email}"
}

resource "google_project_iam_member" "skypilot_iam_service_account_admin" {
  count   = var.orchestrator == "skypilot" ? 1 : 0
  project = data.google_client_config.current.project
  role    = "roles/iam.serviceAccountAdmin"
  member  = "serviceAccount:${google_service_account.zenml_sa.email}"
}

resource "google_project_iam_member" "skypilot_service_account_user" {
  count   = var.orchestrator == "skypilot" ? 1 : 0
  project = data.google_client_config.current.project
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.zenml_sa.email}"
}

resource "google_project_iam_member" "skypilot_service_usage_admin" {
  count   = var.orchestrator == "skypilot" ? 1 : 0
  project = data.google_client_config.current.project
  role    = "roles/serviceusage.serviceUsageAdmin"
  member  = "serviceAccount:${google_service_account.zenml_sa.email}"
}

resource "google_project_iam_member" "skypilot_storage_admin" {
  count   = var.orchestrator == "skypilot" ? 1 : 0
  project = data.google_client_config.current.project
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.zenml_sa.email}"
}


resource "google_project_iam_member" "skypilot_security_admin" {
  count   = var.orchestrator == "skypilot" ? 1 : 0
  project = data.google_client_config.current.project
  role    = "roles/iam.securityAdmin"
  member  = "serviceAccount:${google_service_account.zenml_sa.email}"
}


resource "google_service_account_key" "zenml_sa_key" {
  # When connected to a ZenML Pro tenant, we don't need to create a service
  # account key. We use workload identity federation instead to grant access to
  # the AWS IAM role associated with the ZenML Pro tenant.
  count = local.use_workload_identity ? 0 : 1
  service_account_id = google_service_account.zenml_sa.name
}

resource "google_iam_workload_identity_pool" "workload_identity_pool" {
  count        = local.use_workload_identity ? 1 : 0
  workload_identity_pool_id = "zenml-${random_id.resource_name_suffix.hex}"
}

resource "google_iam_workload_identity_pool_provider" "aws_provider" {
  count        = local.use_workload_identity ? 1 : 0
  workload_identity_pool_id = google_iam_workload_identity_pool.workload_identity_pool[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "zenml-pro-aws"
  attribute_condition                = "attribute.aws_role_name=='${local.zenml_pro_tenant_iam_role_name}'"
  aws {
    account_id = var.zenml_pro_aws_account
  }
  attribute_mapping = {
    "google.subject"      = "assertion.arn"
    "attribute.aws_role_name" = "assertion.arn.extract('assumed-role/{role_name}/')"
  }

  depends_on = [google_project_service.common_services]
}

resource "google_service_account_iam_binding" "workload_identity_binding" {
  count        = local.use_workload_identity ? 1 : 0
  service_account_id = google_service_account.zenml_sa.name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "principalSet://iam.googleapis.com/projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.workload_identity_pool[0].workload_identity_pool_id}/attribute.aws_role_name/${local.zenml_pro_tenant_iam_role_name}"
  ]

  depends_on = [
    google_project_service.common_services,
    google_iam_workload_identity_pool.workload_identity_pool[0],
  ]
}

# We need one more role for the service account if we are using workload
# identity federation: roles/iam.serviceAccountTokenCreator
resource "google_project_iam_member" "service_account_token_creator" {
  count   = local.use_workload_identity ? 1 : 0
  project = data.google_client_config.current.project
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_service_account.zenml_sa.email}"
}


locals {
  # The service connector configuration is different depending on whether we are
  # using the ZenML Pro tenant or not.
  service_connector_config = {
    external_account = {
      project_id = "${data.google_client_config.current.project}"
      external_account_json = local.use_workload_identity ? jsonencode({
        "type": "external_account",
        "audience": "//iam.googleapis.com/projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.workload_identity_pool[0].workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.aws_provider[0].workload_identity_pool_provider_id}",
        "subject_token_type": "urn:ietf:params:aws:token-type:aws4_request",
        "token_url": "https://sts.googleapis.com/v1/token",
        "service_account_impersonation_url": "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${google_service_account.zenml_sa.email}:generateAccessToken",
        "credential_source" = {
          "environment_id": "aws1",
          "region_url": "http://169.254.169.254/latest/meta-data/placement/availability-zone",
          "url": "http://169.254.169.254/latest/meta-data/iam/security-credentials",
          "regional_cred_verification_url": "https://sts.{region}.amazonaws.com?Action=GetCallerIdentity&Version=2011-06-15"
        }
      }) : ""
    }
    service_account = {
      service_account_json = local.use_workload_identity ? "" : google_service_account_key.zenml_sa_key.0.private_key
    }
    service_account_skypilot = {
      service_account_json = local.use_workload_identity ? "" : google_service_account_key.zenml_sa_key.0.private_key
      # The Skypilot orchestrator does not support GCP temporary credentials
      generate_temporary_tokens = false
    }
  }
}

# Artifact Store Component

resource "zenml_service_connector" "gcs" {
  name           = "${var.zenml_stack_name == "" ? "terraform-gcs-${random_id.resource_name_suffix.hex}" : "${var.zenml_stack_name}-gcs"}"
  type           = "gcp"
  auth_method    = local.use_workload_identity ? "external-account" : "service-account"
  resource_type  = "gcs-bucket"
  resource_id    = google_storage_bucket.artifact_store.name

  configuration = local.service_connector_config[local.use_workload_identity ? "external_account" : "service_account"]

  labels = {
    "zenml:provider" = "gcp"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }

  depends_on = [
    google_storage_bucket.artifact_store,
    google_service_account.zenml_sa,
    google_service_account_key.zenml_sa_key,
    google_project_iam_member.storage_object_user,
    google_iam_workload_identity_pool.workload_identity_pool[0],
    google_iam_workload_identity_pool_provider.aws_provider[0],
    google_service_account_iam_binding.workload_identity_binding[0],
    google_project_iam_member.service_account_token_creator[0],
  ]
}

resource "zenml_stack_component" "artifact_store" {
  name      = "${var.zenml_stack_name == "" ? "terraform-gcs-${random_id.resource_name_suffix.hex}" : "${var.zenml_stack_name}-gcs"}"
  type      = "artifact_store"
  flavor    = "gcp"

  configuration = {
    path = "gs://${google_storage_bucket.artifact_store.name}"
  }

  connector_id = zenml_service_connector.gcs.id

  labels = {
    "zenml:provider" = "gcp"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }
}

# Container Registry Component

resource "zenml_service_connector" "gar" {
  name           = "${var.zenml_stack_name == "" ? "terraform-gar-${random_id.resource_name_suffix.hex}" : "${var.zenml_stack_name}-gar"}"
  type           = "gcp"
  auth_method    = local.use_workload_identity ? "external-account" : "service-account"
  resource_type  = "docker-registry"
  # The resource ID for the Google Artifact Registry is in the format:
  # projects/<project-id>/locations/<location>/repositories/<repository-id>
  resource_id    = "projects/${data.google_client_config.current.project}/locations/${data.google_client_config.current.region}/repositories/${google_artifact_registry_repository.container_registry.repository_id}"
  
  configuration = local.service_connector_config[local.use_workload_identity ? "external_account" : "service_account"]

  labels = {
    "zenml:provider" = "gcp"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }

  depends_on = [
    google_artifact_registry_repository.container_registry,
    google_service_account.zenml_sa,
    google_service_account_key.zenml_sa_key,
    google_project_iam_member.artifact_registry_writer,
    google_iam_workload_identity_pool.workload_identity_pool[0],
    google_iam_workload_identity_pool_provider.aws_provider[0],
    google_service_account_iam_binding.workload_identity_binding[0],
    google_project_iam_member.service_account_token_creator[0],
  ]
}

resource "zenml_stack_component" "container_registry" {
  name      = "${var.zenml_stack_name == "" ? "terraform-gar-${random_id.resource_name_suffix.hex}" : "${var.zenml_stack_name}-gar"}"
  type      = "container_registry"
  flavor    = "gcp"

  configuration = {
    uri = "${data.google_client_config.current.region}-docker.pkg.dev/${data.google_client_config.current.project}/${google_artifact_registry_repository.container_registry.repository_id}"
  }

  connector_id = zenml_service_connector.gar.id

  labels = {
    "zenml:provider" = "gcp"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }
}

# Orchestrator

locals {
  # The orchestrator configuration is different depending on the orchestrator
  # chosen by the user. We use the `orchestrator` variable to determine which
  # configuration to use and construct a local variable `orchestrator_config` to
  # hold the configuration.
  orchestrator_config = {
    local = {}
    vertex = {
      location = "${data.google_client_config.current.region}"
      workload_service_account = "${google_service_account.zenml_sa.email}"
    }
    skypilot = {
      region = "${data.google_client_config.current.region}"
    }
    airflow = {
      dag_output_dir = "gs://${google_storage_bucket.artifact_store.name}/dags",
      operator = "kubernetes_pod",
      operator_args = "{\"namespace\": \"composer-user-workloads\", \"config_file\": \"/home/airflow/composer_kube_config\"}"
    }
  }
}

resource "zenml_service_connector" "gcp" {
  name           = "${var.zenml_stack_name == "" ? "terraform-gcp-${random_id.resource_name_suffix.hex}" : "${var.zenml_stack_name}-gcp"}"
  type           = "gcp"
  auth_method    = local.use_workload_identity ? "external-account" : "service-account"
  resource_type  = "gcp-generic"

  configuration = local.service_connector_config[local.use_workload_identity ? "external_account" : (var.orchestrator == "skypilot" ? "service_account_skypilot" : "service_account")]

  labels = {
    "zenml:provider" = "gcp"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }

  depends_on = [
    google_service_account.zenml_sa,
    google_service_account_key.zenml_sa_key,
    google_project_iam_member.storage_object_user,
    google_project_iam_member.artifact_registry_writer,
    google_project_iam_member.ai_platform_service_agent,
    google_project_iam_member.cloud_build_editor,
    google_project_iam_member.cloud_build_builder,
    google_project_iam_member.skypilot_browser[0],
    google_project_iam_member.skypilot_compute_admin[0],
    google_project_iam_member.skypilot_iam_service_account_admin[0],
    google_project_iam_member.skypilot_service_account_user[0],
    google_project_iam_member.skypilot_service_usage_admin[0],
    google_project_iam_member.skypilot_storage_admin[0],
    google_project_iam_member.skypilot_security_admin[0],
    google_iam_workload_identity_pool.workload_identity_pool[0],
    google_iam_workload_identity_pool_provider.aws_provider[0],
    google_service_account_iam_binding.workload_identity_binding[0],
    google_project_iam_member.service_account_token_creator[0],
  ]
}

resource "zenml_stack_component" "orchestrator" {
  name      = "${var.zenml_stack_name == "" ? "terraform-${var.orchestrator}-${random_id.resource_name_suffix.hex}" : "${var.zenml_stack_name}-${var.orchestrator}"}"
  type      = "orchestrator"
  flavor    = var.orchestrator == "skypilot" ? "vm_gcp" : var.orchestrator

  configuration = local.orchestrator_config[var.orchestrator]

  connector_id = contains(["local", "airflow"], var.orchestrator) ? "" : zenml_service_connector.gcp.id

  labels = {
    "zenml:provider" = "gcp"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }
}

# Step Operator
resource "zenml_stack_component" "step_operator" {
  name      = "${var.zenml_stack_name == "" ? "terraform-vertex-${random_id.resource_name_suffix.hex}" : "${var.zenml_stack_name}-vertex"}"
  type      = "step_operator"
  flavor    = "vertex"

  configuration = {
    region = "${data.google_client_config.current.region}",
    service_account = "${google_service_account.zenml_sa.email}"
  }

  connector_id = zenml_service_connector.gcp.id

  labels = {
    "zenml:provider" = "gcp"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }
}

# Image Builder
resource "zenml_stack_component" "image_builder" {
  name      = "${var.zenml_stack_name == "" ? "terraform-gcp-${random_id.resource_name_suffix.hex}" : "${var.zenml_stack_name}-gcp"}"
  type      = "image_builder"
  flavor    = "gcp"

  configuration = {}

  connector_id = zenml_service_connector.gcp.id

  labels = {
    "zenml:provider" = "gcp"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }
}

# Complete Stack
resource "zenml_stack" "stack" {
  name = "${var.zenml_stack_name == "" ? "terraform-gcp-${random_id.resource_name_suffix.hex}" : var.zenml_stack_name}"

  components = {
    artifact_store     = zenml_stack_component.artifact_store.id
    container_registry = zenml_stack_component.container_registry.id
    orchestrator      = zenml_stack_component.orchestrator.id
    step_operator      = zenml_stack_component.step_operator.id
    image_builder      = zenml_stack_component.image_builder.id
  }

  labels = {
    "zenml:provider" = "gcp"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }
}

data "zenml_service_connector" "gcs" {
  id = zenml_service_connector.gcs.id
}

data "zenml_service_connector" "gar" {
  id = zenml_service_connector.gar.id
}

data "zenml_service_connector" "gcp" {
  id = zenml_service_connector.gcp.id
}

data "zenml_stack_component" "artifact_store" {
  id = zenml_stack_component.artifact_store.id
}

data "zenml_stack_component" "container_registry" {
  id = zenml_stack_component.container_registry.id
}

data "zenml_stack_component" "orchestrator" {
  id = zenml_stack_component.orchestrator.id
}

data "zenml_stack_component" "step_operator" {
  id = zenml_stack_component.step_operator.id
}

data "zenml_stack_component" "image_builder" {
  id = zenml_stack_component.image_builder.id
}

data "zenml_stack" "stack" {
  id = zenml_stack.stack.id
}
