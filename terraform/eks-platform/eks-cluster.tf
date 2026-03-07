# =============================================================================
# EKS Cluster
#
# Security hardening applied:
#   ✓ Private node subnets (nodes not publicly reachable)
#   ✓ KMS envelope encryption for Kubernetes Secrets in etcd
#   ✓ All control-plane log types shipped to CloudWatch
#   ✓ Public API endpoint optionally restricted by CIDR
#   ✓ Bottlerocket OS on nodes (immutable, minimal attack surface)
# =============================================================================

resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cloudwatch_log_retention_days
  kms_key_id        = aws_kms_key.cloudwatch.arn
}

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.eks_cluster.arn

  # ── Networking ───────────────────────────────────────────────────────────────
  vpc_config {
    subnet_ids = concat(
      aws_subnet.private[*].id,
      aws_subnet.public[*].id
    )

    security_group_ids = [aws_security_group.cluster_extra.id]

    # Private: control-plane ENIs in private subnets → nodes never need public IPs.
    endpoint_private_access = true

    # Public endpoint: restrict to known CIDRs in production.
    endpoint_public_access       = var.cluster_endpoint_public_access
    public_access_cidrs          = var.cluster_endpoint_public_access_cidrs
  }

  # ── Control-plane logging ────────────────────────────────────────────────────
  enabled_cluster_log_types = var.cluster_log_types

  # ── Secrets encryption at rest ───────────────────────────────────────────────
  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks_secrets.arn
    }
  }

  # ── Kubernetes network config ────────────────────────────────────────────────
  kubernetes_network_config {
    service_ipv4_cidr = "172.20.0.0/16" # does not overlap with VPC CIDR
    ip_family         = "ipv4"
  }

  tags = { Name = var.cluster_name }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
    aws_cloudwatch_log_group.eks_cluster,
  ]
}

# ── aws-auth ConfigMap — grant the node role cluster access ───────────────────
# The aws-auth ConfigMap maps IAM roles/users to Kubernetes RBAC identities.
# The node role MUST be listed so managed node groups can join the cluster.

resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      {
        rolearn  = aws_iam_role.node_group.arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:bootstrappers", "system:nodes"]
      }
    ])
    # Add human/CI user mappings here:
    # mapUsers = yamlencode([
    #   {
    #     userarn  = "arn:aws:iam::ACCOUNT:user/devops-jane"
    #     username = "devops-jane"
    #     groups   = ["system:masters"]
    #   }
    # ])
  }

  depends_on = [aws_eks_cluster.main]
}
