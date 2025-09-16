<div align="center">
  <img referrerpolicy="no-referrer-when-downgrade" src="https://static.scarf.sh/a.png?x-pxid=0fcbab94-8fbe-4a38-93e8-c2348450a42e" />
  <h1 align="center">ZenML Cloud Infrastructure Setup</h1>
</div>

<div align="center">
  <a href="https://zenml.io">
    <img alt="ZenML Logo" src="https://raw.githubusercontent.com/zenml-io/zenml/main/docs/book/.gitbook/assets/header.png" alt="ZenML Logo">
  </a>
  <br />
</div>

---

## ⭐️ Show Your Support

If you find this project helpful, please consider giving ZenML a star on GitHub. Your support helps promote the project and lets others know it's worth checking out.

Thank you for your support! 🌟

[![Star this project](https://img.shields.io/github/stars/zenml-io/zenml?style=social)](https://github.com/zenml-io/zenml/stargazers)

## 🚀 Overview

This Terraform module sets up the necessary GCP infrastructure for a [ZenML](https://zenml.io) stack. It provisions various GCP services and resources, and registers [a ZenML stack](https://docs.zenml.io/user-guide/production-guide/understand-stacks) using these resources with your ZenML server, allowing you to create an internal MLOps platform for your entire machine learning team.

## 🛠 Prerequisites

- Terraform installed (version >= 1.9")
- GCP account set up
- To authenticate with GCP, you need to have [the `gcloud` CLI](https://cloud.google.com/sdk/gcloud)
installed on your machine and you need to have run `gcloud auth application-default login`
to set up your credentials.
- You'll need a Zenml server (version >= 0.62.0) deployed in a remote setting where it can be accessed from GCP. You have the option to either [self-host a ZenML server](https://docs.zenml.io/getting-started/deploying-zenml) or [register for a free ZenML Pro account](https://cloud.zenml.io/signup). Once you have a ZenML Server set up, you also need to create [a ZenML Service Account API key](https://docs.zenml.io/how-to/connecting-to-zenml/connect-with-a-service-account) for your ZenML Server. You can do this by running the following command in a terminal where you have the ZenML CLI installed:

```bash
zenml service-account create <service-account-name>
```

- This Terraform module uses [the ZenML Terraform provider](https://registry.terraform.io/providers/zenml-io/zenml/latest/docs). It is recommended to use environment variables to configure the ZenML Terraform provider with the API key and server URL. You can set the environment variables as follows:

```bash
export ZENML_SERVER_URL="https://your-zenml-server.com"
export ZENML_API_KEY="your-api-key"
```


## 🏗 GCP Resources Created

The Terraform module in this repository creates the following resources in your GCP project:

1. a GCS bucket
2. a Google Artifact Registry
3. a Cloud Composer environment (only if the `orchestrator` variable is set to `airflow`)
4. a Service Account with the minimum necessary permissions to access the GCS bucket, the Google Artifact Registry and the GCP project to build and push container images with Google Cloud Build, store artifacts and run pipelines with Vertex AI, SkyPilot or GCP Cloud Composer and deploy pipelines with Cloud Run.
5. depending on the target ZenML Server capabilities, different authentication methods are used:
  * for a self-hosted ZenML server, a Service Account Key is generated and shared with the ZenML server
  * for a ZenML Pro account, GCP Workload Identity Federation is used to authenticate with the ZenML server, so that no sensitive credentials are shared with the ZenML server. For this, a GCP Workload Identity Pool and a GCP Workload Identity Provider are created and linked to the GCP Service Account. There's only one exception: when the SkyPilot orchestrator is used, this authentication method is not supported, so the Service Account Key is used instead.

## 🧩 ZenML Stack Components

The Terraform module automatically registers a fully functional GCP [ZenML stack](https://docs.zenml.io/user-guide/production-guide/understand-stacks) directly with your ZenML server. The ZenML stack is based on the provisioned GCP resources and is ready to be used to run machine learning pipelines.

The ZenML stack configuration is the following:

1. an GCP Artifact Store linked to the GCS bucket via an AWS Service Connector configured with IAM role credentials
2. an GCP Container Registry linked to the Google Artifact Registry via an AWS Service Connector configured with IAM role credentials
3. depending on the `orchestrator` input variable:
  * if `orchestrator` is set to `local`: a local Orchestrator. This can be used in combination with the Vertex AI Step Operator to selectively run some steps locally and some on Vertex AI.
  * if `orchestrator` is set to `vertex` (default): a Vertex AI Orchestrator linked to the GCP project via an AWS Service Connector configured with IAM role credentials
  * if `orchestrator` is set to `skypilot`: a SkyPilot Orchestrator linked to the GCP project via an AWS Service Connector configured with IAM role credentials
  * if `orchestrator` is set to `airflow`: an Airflow Orchestrator linked to the Cloud Composer environment
4. a Cloud Run Deployer linked to the GCP project via an AWS Service Connector configured with IAM role credentials
5. a Google Cloud Build Image Builder linked to the GCP project via an AWS Service Connector configured with IAM role credentials
6. a Vertex AI Step Operator linked to the GCP project via an AWS Service Connector configured with IAM role credentials
7. a Vertex AI Experiment Tracker linked to the GCP project via an AWS Service Connector configured with IAM role credentials

To use the ZenML stack, you will need to install the required integrations:

* for Vertex AI:

```shell
zenml integration install gcp
```

* for SkyPilot:

```shell
zenml integration install gcp skypilot_gcp
```

* for Airflow:

```shell
zenml integration install gcp airflow
```


## 🚀 Usage

To use this module, aside from the prerequisites mentioned above, you also need to create [a ZenML Service Account API key](https://docs.zenml.io/how-to/connecting-to-zenml/connect-with-a-service-account) for your ZenML Server. You can do this by running the following command in a terminal where you have the ZenML CLI installed:

```bash
zenml service-account create <service-account-name>
```

### Basic Configuration

```hcl
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
    project = "my-project"
}

provider "zenml" {
    # server_url = <taken from the ZENML_SERVER_URL environment variable if not set here>
    # api_key = <taken from the ZENML_API_KEY environment variable if not set here>
}

module "zenml_stack" {
  source  = "zenml-io/zenml-stack/gcp"

  orchestrator = "vertex" # or "skypilot", "airflow" or "local"
  zenml_stack_name = "my-zenml-stack"
}

output "zenml_stack_id" {
  value = module.zenml_stack.zenml_stack.id
}

output "zenml_stack_name" {
  value = module.zenml_stack.zenml_stack.name
}
```

## Terraform Module Details

For detailed information about the module's inputs, outputs, dependencies, and resources, please refer to the official Terraform Registry page:

- [Inputs](https://registry.terraform.io/modules/zenml-io/zenml-stack/gcp/latest?tab=inputs)
- [Outputs](https://registry.terraform.io/modules/zenml-io/zenml-stack/gcp/latest?tab=outputs)
- [Dependencies](https://registry.terraform.io/modules/zenml-io/zenml-stack/gcp/latest?tab=dependencies)
- [Resources](https://registry.terraform.io/modules/zenml-io/zenml-stack/gcp/latest?tab=resources)

