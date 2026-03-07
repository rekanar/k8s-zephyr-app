# =============================================================================
# EKS Managed Add-ons
#
# Managed add-ons are patched and upgraded by AWS — no manual helm releases
# needed for these core components.
#
#   vpc-cni      — pod networking (uses IRSA role to manage ENIs)
#   coredns      — cluster DNS
#   kube-proxy   — iptables rules for Services
#   ebs-csi      — PersistentVolumeClaim support via EBS (uses IRSA)
# =============================================================================

# ── VPC CNI ───────────────────────────────────────────────────────────────────
# ENABLE_PREFIX_DELEGATION: packs more pods per node by assigning IPv4
# prefixes (/28) to ENIs rather than individual IPs.

resource "aws_eks_addon" "vpc_cni" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "vpc-cni"
  resolve_conflicts_on_update = "OVERWRITE"

  # Pin to a version; run `aws eks describe-addon-versions` to find the latest.
  # addon_version = "v1.18.1-eksbuild.1"

  service_account_role_arn = aws_iam_role.vpc_cni_irsa.arn

  configuration_values = jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = "1"
    }
  })

  tags = { Name = "vpc-cni" }

  depends_on = [aws_eks_node_group.system]
}

# ── CoreDNS ───────────────────────────────────────────────────────────────────

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = { Name = "coredns" }

  depends_on = [aws_eks_node_group.system]
}

# ── kube-proxy ────────────────────────────────────────────────────────────────

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = { Name = "kube-proxy" }

  depends_on = [aws_eks_cluster.main]
}

# ── EBS CSI driver ───────────────────────────────────────────────────────────
# Needed if any workload uses PersistentVolumeClaims backed by EBS.

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_update = "OVERWRITE"

  service_account_role_arn = aws_iam_role.ebs_csi_irsa.arn

  tags = { Name = "ebs-csi" }

  depends_on = [aws_eks_node_group.system]
}

# ── StorageClass using EBS gp3 ────────────────────────────────────────────────

resource "kubernetes_storage_class" "ebs_gp3" {
  metadata {
    name = "ebs-gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer" # avoids AZ mismatch

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }

  depends_on = [aws_eks_addon.ebs_csi]
}
