# Deploying with Terraform

This directory contains two Terraform stacks for deploying the Zephyr Archaeotech Emporium Online Store to AWS:

| Stack | Directory | Purpose |
|-------|-----------|---------|
| **EKS Platform** | `terraform/eks-platform/` | Provisions the EKS cluster, VPC, IAM roles, add-ons, and security infrastructure |
| **Application** | `terraform/` | Builds and pushes container images to ECR, then deploys all Kubernetes workloads |

Deploy the **EKS Platform** stack first; the **Application** stack depends on it.

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured for your account (`aws configure`)
- [Docker](https://docs.docker.com/get-docker/) (required by the application stack to build images)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) for inspecting the cluster after deployment

---

## Step 1 — Deploy the EKS Platform Stack

The platform stack creates:
- A VPC with public and private subnets across multiple availability zones
- An EKS cluster with managed node groups (system + application)
- KMS encryption for cluster secrets
- IAM roles and IRSA bindings for cluster add-ons
- EKS managed add-ons (CoreDNS, kube-proxy, VPC CNI, EBS CSI)
- Cluster Autoscaler and AWS Load Balancer Controller (via Helm)
- HPA, PDB, and network policies for resilience
- VPC Flow Logs for network audit

```bash
cd terraform/eks-platform
```

### Configure variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your desired values. Key settings:

```hcl
aws_region   = "us-east-1"
environment  = "test"
cluster_name = "zephyr-eks"

# Kubernetes version — verify availability:
#   aws eks describe-addon-versions --query 'addons[0].addonVersions[].compatibilities[].clusterVersion' \
#     --output text | tr '\t' '\n' | sort -u
cluster_version = "1.29"

# Tighten public access CIDRs in production:
cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
```

### Apply

```bash
terraform init
terraform plan
terraform apply
```

### Retrieve the kubeconfig

```bash
terraform output -raw kubeconfig > kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
```

---

## Step 2 — Deploy the Application Stack

The application stack depends on:
1. A running EKS cluster (from Step 1 or the existing Pulumi platform stack)
2. Aurora RDS endpoints for the catalog and orders databases (from the [`zephyr-data`](https://github.com/pulumi/zephyr-data) stack)

```bash
cd terraform    # repository root's terraform/ directory
```

### Configure variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`. The required values are:

```hcl
aws_region  = "us-east-1"
environment = "test"

# Path to the kubeconfig obtained in Step 1:
kubeconfig_path = "./kubeconfig"

# Database endpoints — retrieve from the zephyr-data Pulumi stack:
#   pulumi stack -C <path-to-zephyr-data> output catalogDbEndpoint
#   pulumi stack -C <path-to-zephyr-data> output ordersDbEndpoint
catalog_db_endpoint = "mydb-catalog.cluster-xxxx.us-east-1.rds.amazonaws.com"
orders_db_endpoint  = "mydb-orders.cluster-xxxx.us-east-1.rds.amazonaws.com"

catalog_db_password = "change_me"   # use a secrets manager in production
orders_db_password  = "change_me"

# Tag for locally built Docker images; bump to force a rebuild:
app_image_tag = "latest"
```

### Copy the kubeconfig

```bash
cp ../eks-platform/kubeconfig ./kubeconfig
```

Or specify a path directly in `terraform.tfvars` via `kubeconfig_path`.

### Apply

```bash
terraform init
terraform plan
terraform apply
```

Terraform will:
1. Create an ECR repository for the application images
2. Build and push the `assets`, `catalog`, and `ui` Docker images
3. Deploy all Kubernetes namespaces, ConfigMaps, Secrets, Deployments, and Services

### Access the application

```bash
terraform output ui_load_balancer_hostname
```

Open `http://<hostname>` in your browser. Allow a minute or two for the load balancer to become active.

---

## Remote State (Recommended for Teams)

Both stacks ship with a commented-out S3 backend configuration in their `main.tf`. Uncomment and configure it for collaborative use:

```hcl
backend "s3" {
  bucket         = "my-terraform-state-bucket"
  key            = "zephyr-app/test/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "terraform-state-lock"
  encrypt        = true
}
```

Create the S3 bucket and DynamoDB table before running `terraform init`.

Once both stacks use remote state you can replace the manual `kubeconfig_path` and `catalog_db_endpoint` variables with `terraform_remote_state` data sources (see the commented examples in `terraform/main.tf`).

---

## Teardown

To destroy resources, run `terraform destroy` in each stack in **reverse** order:

```bash
# 1. Remove application workloads
cd terraform
terraform destroy

# 2. Remove EKS platform infrastructure
cd terraform/eks-platform
terraform destroy
```

> **Warning:** `terraform destroy` on the platform stack deletes the EKS cluster, VPC, and all associated AWS resources. Ensure you no longer need any data stored in the cluster before proceeding.
