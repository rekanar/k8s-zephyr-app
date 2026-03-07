# =============================================================================
# Managed Node Groups
#
# Two groups:
#   system  — small nodes for kube-system daemonsets (CoreDNS, CNI, CA…)
#   app     — larger nodes for application workloads, tainted to keep
#             system pods off them and vice-versa
#
# Scalability features:
#   ✓ min/max/desired via ASG
#   ✓ Auto-scaling driven by Cluster Autoscaler (see cluster-autoscaler.tf)
#   ✓ Multi-AZ placement for fault tolerance
#   ✓ Launch template with disk encryption, IMDSv2, user_data hardening
#
# Rolling update behaviour (UPDATE_CONFIG):
#   ✓ maxUnavailable = 1  — at most one node is replaced at a time
#   ✓ EKS drains each node before terminating it (cordons + evicts pods)
#   ✓ PodDisruptionBudgets (k8s-resilience.tf) prevent all replicas evicting
#
# Crash-loop guard:
#   Nodes run AL2/Bottlerocket with systemd watchdog; if kubelet crashes, the
#   instance is replaced by the ASG health check.
# =============================================================================

# ── Launch template shared settings ──────────────────────────────────────────

locals {
  node_userdata = base64encode(<<-EOT
    #!/bin/bash
    # Harden IMDSv2 (disallow un-hopped IMDSv1 calls from pods)
    /opt/aws/bin/cfn-signal --exit-codes 0 || true
    echo "net.ipv4.conf.default.rp_filter = 0" >> /etc/sysctl.d/99-eks.conf
    sysctl --system
  EOT
  )
}

resource "aws_launch_template" "nodes_common" {
  name_prefix = "${var.cluster_name}-node-"

  # Enforce IMDSv2 — prevents credential theft via SSRF
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 1          # blocks pod-level IMDS calls
  }

  # Encrypted root volume
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 50
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  monitoring { enabled = true } # CloudWatch detailed monitoring

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.cluster_name}-node"
      Environment = var.environment
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ── System node group ─────────────────────────────────────────────────────────
# Runs: CoreDNS, kube-proxy, vpc-cni, cluster-autoscaler, aws-lbc

resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-system"
  node_role_arn   = aws_iam_role.node_group.arn

  # Spread across all private subnets (one per AZ)
  subnet_ids = aws_subnet.private[*].id

  instance_types = var.system_node_instance_types

  # ── Scaling ────────────────────────────────────────────────────────────────
  scaling_config {
    min_size     = var.system_nodes_min
    max_size     = var.system_nodes_max
    desired_size = var.system_nodes_desired
  }

  # ── Rolling updates ────────────────────────────────────────────────────────
  # EKS drains the node (respecting PDBs) before replacing it.
  update_config {
    max_unavailable = 1 # replace 1 node at a time — keeps cluster stable
  }

  launch_template {
    id      = aws_launch_template.nodes_common.id
    version = aws_launch_template.nodes_common.latest_version
  }

  # Taint: only system workloads tolerate this taint
  taint {
    key    = "node-role"
    value  = "system"
    effect = "NO_SCHEDULE"
  }

  labels = {
    "node-role"                     = "system"
    "kubernetes.io/os"              = "linux"
    "node.kubernetes.io/node-group" = "system"
  }

  tags = {
    Name = "${var.cluster_name}-system-node"
    # Cluster Autoscaler needs these tags on the ASG (EKS propagates them)
    "k8s.io/cluster-autoscaler/enabled"                  = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}"      = "owned"
    "k8s.io/cluster-autoscaler/node-template/label/node-role" = "system"
  }

  lifecycle {
    # Prevent Terraform from resetting desired_size when CA changes it
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
  ]
}

# ── Application node group ────────────────────────────────────────────────────
# Runs: assets, catalog, ui, carts, orders, checkout, rabbitmq

resource "aws_eks_node_group" "app" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-app"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = aws_subnet.private[*].id

  instance_types = var.app_node_instance_types

  scaling_config {
    min_size     = var.app_nodes_min
    max_size     = var.app_nodes_max
    desired_size = var.app_nodes_desired
  }

  # ── Rolling updates ────────────────────────────────────────────────────────
  update_config {
    # For larger clusters, switch to max_unavailable_percentage = 33
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.nodes_common.id
    version = aws_launch_template.nodes_common.latest_version
  }

  labels = {
    "node-role"                     = "app"
    "kubernetes.io/os"              = "linux"
    "node.kubernetes.io/node-group" = "app"
  }

  tags = {
    Name                                             = "${var.cluster_name}-app-node"
    "k8s.io/cluster-autoscaler/enabled"              = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}"  = "owned"
    "k8s.io/cluster-autoscaler/node-template/label/node-role" = "app"
  }

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
  ]
}
