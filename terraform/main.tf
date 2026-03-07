terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

  # Configure your remote state backend.
  # Example using S3 (recommended for team use):
  #
  # backend "s3" {
  #   bucket         = "my-terraform-state-bucket"
  #   key            = "zephyr-app/${var.environment}/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-state-lock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "zephyr-app"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# The kubernetes provider connects to the EKS cluster.
#
# Option A (current): supply a kubeconfig file path via var.kubeconfig_path.
#   Obtain it after the platform stack is applied:
#     pulumi stack output kubeconfig > kubeconfig   (Pulumi)
#     terraform output kubeconfig > kubeconfig       (Terraform, once zephyr-k8s is migrated)
#
# Option B: pass cluster endpoint + CA cert + token directly (see commented block below).
provider "kubernetes" {
  config_path    = var.kubeconfig_path != "" ? var.kubeconfig_path : null
  config_context = var.kubeconfig_context != "" ? var.kubeconfig_context : null

  # Option B — uncomment when consuming outputs from the zephyr-k8s Terraform stack:
  # host                   = data.terraform_remote_state.platform.outputs.cluster_endpoint
  # cluster_ca_certificate = base64decode(data.terraform_remote_state.platform.outputs.cluster_ca_cert)
  # token                  = data.terraform_remote_state.platform.outputs.cluster_token
}

# ------------------------------------------------------------------------------
# Remote state references
#
# Once zephyr-k8s and zephyr-data are migrated to Terraform (with an S3 backend),
# replace the input variables for cluster/db info with these data sources:
#
# data "terraform_remote_state" "platform" {
#   backend = "s3"
#   config = {
#     bucket = var.platform_state_bucket
#     key    = "zephyr-k8s/${var.environment}/terraform.tfstate"
#     region = var.aws_region
#   }
# }
#
# data "terraform_remote_state" "data_layer" {
#   backend = "s3"
#   config = {
#     bucket = var.data_state_bucket
#     key    = "zephyr-data/${var.environment}/terraform.tfstate"
#     region = var.aws_region
#   }
# }
#
# Then replace var.catalog_db_endpoint with:
#   data.terraform_remote_state.data_layer.outputs.catalog_db_endpoint
# And var.orders_db_endpoint with:
#   data.terraform_remote_state.data_layer.outputs.orders_db_endpoint
# ------------------------------------------------------------------------------
