variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name (e.g. test, prod). Used for tagging and state key namespacing."
  type        = string
  default     = "test"
}

# ── Kubernetes access ──────────────────────────────────────────────────────────

variable "kubeconfig_path" {
  description = "Path to the kubeconfig file for the EKS cluster. Leave empty to fall back to ~/.kube/config."
  type        = string
  default     = ""
}

variable "kubeconfig_context" {
  description = "Kubeconfig context to use. Leave empty to use the current context."
  type        = string
  default     = ""
}

# ── Database endpoints (from zephyr-data stack) ────────────────────────────────
# These map to the Pulumi StackReference outputs: catalogDbEndpoint / ordersDbEndpoint.
# Once zephyr-data is migrated to Terraform, replace these with
# data.terraform_remote_state.data_layer.outputs.* (see main.tf).

variable "catalog_db_endpoint" {
  description = "Hostname of the Aurora catalog database (without port). Example: mydb.cluster-xxxx.us-east-1.rds.amazonaws.com"
  type        = string
}

variable "orders_db_endpoint" {
  description = "Hostname of the Aurora orders database (without port). Example: mydb.cluster-xxxx.us-east-1.rds.amazonaws.com"
  type        = string
}

variable "catalog_db_password" {
  description = "Password for the catalog database user."
  type        = string
  sensitive   = true
  default     = "default_password"
}

variable "orders_db_password" {
  description = "Password for the orders database user."
  type        = string
  sensitive   = true
  default     = "default_password"
}

# ── Image configuration ────────────────────────────────────────────────────────

variable "app_image_tag" {
  description = "Tag applied to locally built Docker images (assets, catalog, ui). Change this to force a rebuild."
  type        = string
  default     = "latest"
}

# ── Remote state bucket names (used once platform/data stacks move to Terraform) ──

variable "platform_state_bucket" {
  description = "S3 bucket holding the zephyr-k8s Terraform state. Only needed after migrating the platform stack."
  type        = string
  default     = ""
}

variable "data_state_bucket" {
  description = "S3 bucket holding the zephyr-data Terraform state. Only needed after migrating the data stack."
  type        = string
  default     = ""
}
