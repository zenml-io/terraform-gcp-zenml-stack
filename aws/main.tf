terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 1.19"
    }
  }
}

provider "aws" {
  region = var.region
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

data "aws_caller_identity" "current" {}

resource "random_id" "resource_name_suffix" {
  # This will generate a string of 12 characters, encoded as base64 which makes
  # it 8 characters long
  byte_length = 6
}

resource "aws_s3_bucket" "artifact_store" {
  bucket = "zenml-${data.aws_caller_identity.current.account_id}-${random_id.resource_name_suffix.hex}"
}

resource "aws_ecr_repository" "container_registry" {
  name = "zenml-${random_id.resource_name_suffix.hex}"
}


resource "aws_iam_user" "iam_user" {
  name = "zenml-${random_id.resource_name_suffix.hex}"
}

resource "aws_iam_user_policy" "assume_role_policy" {
  name = "AssumeRole"
  user = aws_iam_user.iam_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_access_key" "iam_user_access_key" {
  user = aws_iam_user.iam_user.name
}

resource "aws_iam_role" "stack_access_role" {
  name               = "zenml-${random_id.resource_name_suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_user.iam_user.arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "s3_policy" {
  name = "S3Policy"
  role = aws_iam_role.stack_access_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.artifact_store.arn,
          "${aws_s3_bucket.artifact_store.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "sagemaker_runtime_role" {
  name               = "zenml-${random_id.resource_name_suffix.hex}-sagemaker"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
  ]
}


resource "aws_iam_role_policy" "ecr_policy" {
  name = "ECRPolicy"
  role = aws_iam_role.stack_access_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:DescribeRegistry",
          "ecr:BatchGetImage",
          "ecr:DescribeImages",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = aws_ecr_repository.container_registry.arn
      },
      {
        Effect = "Allow"
        Action = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:DescribeRepositories",
          "ecr:ListRepositories"
        ]
        Resource = "arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "sagemaker_policy" {
  name = "SageMakerPolicy"
  role = aws_iam_role.stack_access_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sagemaker:CreatePipeline",
          "sagemaker:StartPipelineExecution",
          "sagemaker:DescribePipeline",
          "sagemaker:DescribePipelineExecution"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = aws_iam_role.sagemaker_runtime_role.arn
      }
    ]
  })
}

resource "restapi_object" "zenml_stack" {
  provider = restapi.zenml_api
  path = "/api/v1/stacks"
  create_path = "/api/v1/workspaces/default/full-stack"
  data = <<EOF
{
  "name": "terraform-aws-stack-${random_id.resource_name_suffix.hex}",
  "description": "Deployed with the ZenML AWS Stack Terraform module in the '${data.aws_caller_identity.current.account_id}' account and '${var.region}' region.",
  "labels": {
    "zenml:provider": "aws",
    "zenml:deployment": "terraform"
  },
  "service_connectors": [
    {
      "type": "aws",
      "auth_method": "iam-role",
      "configuration": {
        "aws_access_key_id": "${aws_iam_access_key.iam_user_access_key.id}",
        "aws_secret_access_key": "${aws_iam_access_key.iam_user_access_key.secret}",
        "region": "${var.region}",
        "role_arn": "${aws_iam_role.stack_access_role.arn}"
      }
    }
  ],
  "components": {
    "artifact_store": {
      "flavor": "s3",
      "service_connector_index": 0,
      "configuration": {
        "path": "s3://${aws_s3_bucket.artifact_store.bucket}"
      }
    },
    "container_registry":{
      "flavor": "aws",
      "service_connector_index": 0,
      "configuration": {
        "uri": "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com",
        "default_repository": "${aws_ecr_repository.container_registry.name}"
      }
    },
    "orchestrator": {
      "flavor": "sagemaker",
      "service_connector_index": 0,
      "configuration": {
        "location": "${var.region}",
        "execution_role": "${aws_iam_role.sagemaker_runtime_role.arn}"
      }
    },
    "image_builder": {
      "flavor": "local"
    }
  }
}
EOF
  lifecycle {
    # Given that we don't yet support updating a full stack, we force a new
    # resource to be created whenever any of the inputs change.
    replace_triggered_by = [
      random_id.resource_name_suffix,
      aws_s3_bucket.artifact_store,
      aws_ecr_repository.container_registry,
      aws_iam_access_key.iam_user_access_key,
      aws_iam_role.stack_access_role,
      aws_iam_role.sagemaker_runtime_role
    ]
  }
}