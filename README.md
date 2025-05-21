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
4. a Service Account with the minimum necessary permissions to access the GCS bucket, the Google Artifact Registry and the GCP project to build and push container images with Google Cloud Build, store artifacts and run pipelines with Vertex AI, SkyPilot or GCP Cloud Composer.
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
4. a Google Cloud Build Image Builder linked to the GCP project via an AWS Service Connector configured with IAM role credentials
5. a Vertex AI Step Operator linked to the GCP project via an AWS Service Connector configured with IAM role credentials
6. a Vertex AI Experiment Tracker linked to the GCP project via an AWS Service Connector configured with IAM role credentials

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

## Requirements

| Name                                                                      | Version     |
| ------------------------------------------------------------------------- | ----------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0      |
| <a name="requirement_google"></a> [google](#requirement\_google)          | ~> 5.0      |
| <a name="requirement_zenml"></a> [zenml](#requirement\_zenml)             | any version |

## Providers

| Name                                                       | Version |
| ---------------------------------------------------------- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | ~> 5.0  |
| <a name="provider_random"></a> [random](#provider\_random) | n/a     |
| <a name="provider_zenml"></a> [zenml](#provider\_zenml)    | n/a     |

## Inputs

| Name                                                                                                              | Description                                                                                              | Type       | Default     | Required |
| ----------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ---------- | ----------- | :------: |
| <a name="input_artifact_store_config"></a> [artifact\_store\_config](#input\_artifact\_store\_config)             | Configuration for the artifact store.                                                                    | `map(any)` | `{}`        |    no    |
| <a name="input_container_registry_config"></a> [container\_registry\_config](#input\_container\_registry\_config) | Configuration for the container registry.                                                                | `map(any)` | `{}`        |    no    |
| <a name="input_experiment_tracker_config"></a> [experiment\_tracker\_config](#input\_experiment\_tracker\_config) | Configuration for the experiment tracker.                                                                | `map(any)` | `{}`        |    no    |
| <a name="input_image_builder_config"></a> [image\_builder\_config](#input\_image\_builder\_config)                | Configuration for the image builder.                                                                     | `map(any)` | `{}`        |    no    |
| <a name="input_labels"></a> [labels](#input\_labels)                                                              | A map of labels to apply to all GCP resources created by this module.                                    | `map(string)` | `{}`        |    no    |
| <a name="input_orchestrator"></a> [orchestrator](#input\_orchestrator)                                            | The orchestrator to use for the ZenML stack. Valid values are: `local`, `vertex`, `skypilot`, `airflow`. | `string`   | `"vertex"`  |    no    |
| <a name="input_orchestrator_config"></a> [orchestrator\_config](#input\_orchestrator\_config)                     | Configuration for the orchestrator.                                                                      | `map(any)` | `{}`        |    no    |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id)                                                | The GCP project ID to deploy resources in. If not set, the provider's project ID will be used.           | `string`   | `null`      |    no    |
| <a name="input_region"></a> [region](#input\_region)                                                              | The GCP region to deploy resources in. If not set, the provider's region will be used.                   | `string`   | `null`      |    no    |
| <a name="input_step_operator_config"></a> [step\_operator\_config](#input\_step\_operator\_config)                | Configuration for the step operator.                                                                     | `map(any)` | `{}`        |    no    |
| <a name="input_zenml_stack_deployment"></a> [zenml\_stack\_deployment](#input\_zenml\_stack\_deployment)          | The name of the ZenML stack deployment. This is used to label resources created by this module.          | `string`   | `"default"` |    no    |
| <a name="input_zenml_stack_name"></a> [zenml\_stack\_name](#input\_zenml\_stack\_name)                            | The name of the ZenML stack to create. If not set, a random name will be generated.                      | `string`   | `""`        |    no    |


## 🎓 Learning Resources

[ZenML Documentation](https://docs.zenml.io/)
[ZenML Starter Guide](https://docs.zenml.io/user-guide/starter-guide)
[ZenML Examples](https://github.com/zenml-io/zenml/tree/main/examples)
[ZenML Blog](https://www.zenml.io/blog)

## 🆘 Getting Help
If you need assistance, join our Slack community or open an issue on our GitHub repo.


<div>
<p align="left">
    <div align="left">
      Join our <a href="https://zenml.io/slack" target="_blank">
      <img width="18" src="https://cdn3.iconfinder.com/data/icons/logos-and-brands-adobe/512/306_Slack-512.png" alt="Slack"/>
    <b>Slack Community</b> </a> and be part of the ZenML family.
    </div>
    <br />
    <a href="https://zenml.io/features">Features</a>
    ·
    <a href="https://zenml.io/roadmap">Roadmap</a>
    ·
    <a href="https://github.com/zenml-io/zenml/issues">Report Bug</a>
    ·
    <a href="https://zenml.io/cloud">Sign up for ZenML Pro</a>
    ·
    <a href="https://www.zenml.io/blog">Read Blog</a>
    ·
    <a href="https://github.com/zenml-io/zenml/issues?q=is%3Aopen+is%3Aissue+archived%3Afalse+label%3A%22good+first+issue%22">Contribute to Open Source</a>
    ·
    <a href="https://github.com/zenml-io/zenml-projects">Projects Showcase</a>
  </p>
</div>
