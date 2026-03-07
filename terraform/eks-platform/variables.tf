variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name (e.g. test, staging, prod)."
  type        = string
  default     = "test"
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "zephyr-eks"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.29"
}

# ── Networking ────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to use (min 2 for HA)."
  type        = number
  default     = 3
}

# ── Cluster endpoint access ───────────────────────────────────────────────────

variable "cluster_endpoint_public_access" {
  description = "Whether the EKS API server public endpoint is enabled."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint. Restrict to your office/VPN IPs in production."
  type        = list(string)
  default     = ["0.0.0.0/0"] # tighten in prod: ["203.0.113.0/24"]
}

# ── Node groups ───────────────────────────────────────────────────────────────

variable "system_node_instance_types" {
  description = "EC2 instance types for system (kube-system) node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "app_node_instance_types" {
  description = "EC2 instance types for application node group."
  type        = list(string)
  default     = ["t3.large"]
}

variable "system_nodes_min" { type = number; default = 1 }
variable "system_nodes_max" { type = number; default = 3 }
variable "system_nodes_desired" { type = number; default = 2 }

variable "app_nodes_min" { type = number; default = 2 }
variable "app_nodes_max" { type = number; default = 10 }
variable "app_nodes_desired" { type = number; default = 3 }

# ── Logging ───────────────────────────────────────────────────────────────────

variable "cluster_log_types" {
  description = "EKS control plane log types to enable."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log group retention period in days. Minimum 90 days recommended for audit compliance."
  type        = number
  default     = 90
}

# ── Add-ons ───────────────────────────────────────────────────────────────────

variable "cluster_autoscaler_version" {
  description = "Cluster Autoscaler Helm chart version."
  type        = string
  default     = "9.37.0"
}

variable "aws_lbc_version" {
  description = "AWS Load Balancer Controller Helm chart version."
  type        = string
  default     = "1.7.2"
}
