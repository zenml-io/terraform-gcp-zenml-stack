<div align="center">
  <img referrerpolicy="no-referrer-when-downgrade" src="https://static.scarf.sh/a.png?x-pxid=0fcbab94-8fbe-4a38-93e8-c2348450a42e" />
  <h1 align="center">ZenML GCP Infrastructure Setup</h1>
</div>

<div align="center">
  <a href="https://zenml.io">
    <img alt="ZenML Logo" src="https://raw.githubusercontent.com/zenml-io/zenml/main/docs/book/.gitbook/assets/header.png" alt="ZenML Logo">
  </a>
  <br />

  [![PyPi][pypi-shield]][pypi-url]
  [![PyPi][pypiversion-shield]][pypi-url]
  [![PyPi][downloads-shield]][downloads-url]
  [![License][license-shield]][license-url]
</div>

[pypi-shield]: https://img.shields.io/pypi/pyversions/zenml?color=281158
[pypi-url]: https://pypi.org/project/zenml/
[pypiversion-shield]: https://img.shields.io/pypi/v/zenml?color=361776
[downloads-shield]: https://img.shields.io/pypi/dm/zenml?color=431D93
[downloads-url]: https://pypi.org/project/zenml/
[license-shield]: https://img.shields.io/github/license/zenml-io/zenml?color=9565F6
[license-url]: https://github.com/zenml-io/zenml/blob/main/LICENSE

---

## ⭐️ Show Your Support

If you find this project helpful, please consider giving ZenML a star on GitHub. Your support helps promote the project and lets others know it's worth checking out.

Thank you for your support! 🌟

[![Star this project](https://img.shields.io/github/stars/zenml-io/zenml?style=social)](https://github.com/zenml-io/zenml/stargazers)

## 🚀 Overview

This Terraform configuration sets up the necessary Google Cloud Platform (GCP) infrastructure for a [ZenML](https://zenml.io) stack. It provisions various GCP services and resources, and configures a ZenML stack using these resources, allowing you to create an internal MLOps platform for your entire machine learning team.

## 🛠 Prerequisites

- Terraform installed (version compatible with provider "~> 4.0")
- Cloud provider account and project set up
- [ZenML installed and configured](https://docs.zenml.io/getting-started/installation)
- Relevant CLI tools for your chosen cloud provider installed and authenticated

## 🏗 Resources Created

The Terraform configurations in this repository create various cloud resources, which may include:

1. Required cloud APIs and services
2. Storage solutions for artifacts
3. Container registries
4. Service accounts with necessary permissions
5. Authentication keys or tokens

Specific resources will depend on the chosen cloud provider and module.

## 🧩 ZenML Stack Components

The configurations set up the following [ZenML stack components](https://docs.zenml.io/user-guide/production-guide/understand-stacks):

1. Cloud-specific Service Connector
2. Container Registry
3. Artifact Store
4. Orchestrator

Specific components may vary based on the cloud provider and chosen configuration.

## 🚀 Usage

1. Navigate to the directory for your chosen cloud provider
2. Set up your Terraform variables (create a `terraform.tfvars` file or use environment variables)
3. Initialize Terraform: `terraform init`
4. Plan the Terraform execution: `terraform plan`
5. Apply the Terraform configuration: `terraform apply`

After successful application, your ZenML stack will be set up and ready to use.

## 🧹 Cleanup

To destroy the created resources and remove the ZenML stack configuration:

```bash
terraform destroy
```

## 📝 Notes

The ZenML stack setup and cleanup processes are logged to zenml_stack_setup.log and zenml_stack_cleanup.log respectively.
Ensure you have the necessary permissions in your GCP project to create these resources.
Always review the changes before applying them, especially in a production environment.

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
