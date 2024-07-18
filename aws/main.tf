terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Enable required AWS services
resource "aws_s3_bucket" "artifact_store" {
  bucket = "zenml-artifact-store-${var.name_suffix}"
}

resource "aws_ecr_repository" "container_registry" {
  name = "zenml-container-registry-${var.name_suffix}"
}

resource "aws_iam_role" "zenml_role" {
  name = "zenml-role-${lower(replace(var.name_suffix, "_", "-"))}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
      }
    ]
  })
}

# Attach policies to the IAM role
resource "aws_iam_role_policy_attachment" "s3_full_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.zenml_role.name
}

resource "aws_iam_role_policy_attachment" "ecr_full_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
  role       = aws_iam_role.zenml_role.name
}

resource "aws_iam_role_policy_attachment" "sagemaker_full_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
  role       = aws_iam_role.zenml_role.name
}

resource "null_resource" "zenml_stack" {
  depends_on = [
    aws_s3_bucket.artifact_store,
    aws_ecr_repository.container_registry,
    aws_iam_role.zenml_role,
    aws_iam_role_policy_attachment.s3_full_access,
    aws_iam_role_policy_attachment.ecr_full_access,
    aws_iam_role_policy_attachment.sagemaker_full_access
  ]

  provisioner "local-exec" {
    command = <<-EOT
      {
        zenml integration install aws s3 -y
        zenml connect --url=${var.zenml_server_url} --api-key=${var.zenml_api_token}
        
        # Register AWS Service Connector
        zenml service-connector register aws-connector-${var.name_suffix} \
          --type aws \
          --auth-method iam-role \
          --role_arn=${aws_iam_role.zenml_role.arn} \
          --region=${var.region}

        # Register and connect AWS ECR Container Registry
        zenml container-registry register ecr-${var.name_suffix} \
          --flavor=aws \
          --uri=${aws_ecr_repository.container_registry.repository_url}
        zenml container-registry connect ecr-${var.name_suffix} --connector aws-connector-${var.name_suffix}

        # Register other stack components
        zenml artifact-store register s3-${var.name_suffix} --flavor=s3 --path=s3://${aws_s3_bucket.artifact_store.id}
        zenml artifact-store connect s3-${var.name_suffix} --connector aws-connector-${var.name_suffix}

        zenml orchestrator register sagemaker-${var.name_suffix} --flavor=sagemaker --execution_role=${aws_iam_role.zenml_role.arn}
        zenml orchestrator connect sagemaker-${var.name_suffix} --connector aws-connector-${var.name_suffix}

        # Register and set the stack
        zenml stack register aws-stack-${var.name_suffix} \
          -a s3-${var.name_suffix} \
          -c ecr-${var.name_suffix} \
          -o sagemaker-${var.name_suffix} \
          --set
        
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
        zenml stack delete aws-stack-${self.triggers.name_suffix} -y || echo "Failed to delete stack, it may not exist"
        zenml artifact-store delete s3-${self.triggers.name_suffix} || echo "Failed to delete artifact store, it may not exist"
        zenml container-registry delete ecr-${self.triggers.name_suffix} || echo "Failed to delete container registry, it may not exist"
        zenml orchestrator delete sagemaker-${self.triggers.name_suffix} || echo "Failed to delete orchestrator, it may not exist"
        zenml service-connector delete aws-connector-${self.triggers.name_suffix} || echo "Failed to delete service connector, it may not exist"
      } >> zenml_stack_cleanup.log 2>&1
      
      if [ $? -ne 0 ]; then
        echo "An error occurred during ZenML stack cleanup. Check zenml_stack_cleanup.log for details."
        exit 1
      fi
    EOT
  }
}