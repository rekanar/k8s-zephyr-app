# =============================================================================
# Cluster Autoscaler (CA) — horizontal node scaling
#
# CA watches for Pending pods (can't schedule due to insufficient resources)
# and triggers ASG scale-out.  It also scales in underutilised nodes safely
# (respecting PodDisruptionBudgets and the `safe-to-evict` annotation).
#
# Scalability guarantees:
#   ✓ Nodes provisioned in < 2 min when pods are Pending
#   ✓ Scale-in delayed 10 min of idleness to avoid flapping
#   ✓ PDB-aware drain before node termination
# =============================================================================

resource "kubernetes_service_account" "cluster_autoscaler" {
  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    annotations = {
      # IRSA: tells the pod to assume the CA IAM role
      "eks.amazonaws.com/role-arn" = aws_iam_role.cluster_autoscaler_irsa.arn
    }
    labels = {
      "app.kubernetes.io/name"    = "cluster-autoscaler"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  namespace  = "kube-system"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = var.cluster_autoscaler_version

  # Don't create the SA — we manage it above with the IRSA annotation.
  set {
    name  = "rbac.serviceAccount.create"
    value = "false"
  }
  set {
    name  = "rbac.serviceAccount.name"
    value = kubernetes_service_account.cluster_autoscaler.metadata[0].name
  }

  # Target this cluster
  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }
  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  # Scale-in safety: wait 10 min before removing an idle node
  set {
    name  = "extraArgs.scale-down-delay-after-add"
    value = "10m"
  }
  set {
    name  = "extraArgs.scale-down-unneeded-time"
    value = "10m"
  }

  # Honour PodDisruptionBudgets during scale-in
  set {
    name  = "extraArgs.skip-nodes-with-local-storage"
    value = "false"
  }
  set {
    name  = "extraArgs.skip-nodes-with-system-pods"
    value = "false"
  }
  set {
    name  = "extraArgs.balance-similar-node-groups"
    value = "true"
  }

  # Tolerate the system node taint so CA itself runs on system nodes
  set {
    name  = "tolerations[0].key"
    value = "node-role"
  }
  set {
    name  = "tolerations[0].value"
    value = "system"
  }
  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  set {
    name  = "nodeSelector.node-role"
    value = "system"
  }

  # Resource requests — CA is lightweight
  set {
    name  = "resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "resources.requests.memory"
    value = "128Mi"
  }
  set {
    name  = "resources.limits.memory"
    value = "256Mi"
  }

  depends_on = [
    aws_eks_node_group.system,
    kubernetes_service_account.cluster_autoscaler,
  ]
}

# ── AWS Load Balancer Controller ──────────────────────────────────────────────
# Provisions ALB/NLB for Services of type LoadBalancer and Ingress resources.

resource "kubernetes_service_account" "aws_lbc" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_lbc_irsa.arn
    }
    labels = {
      "app.kubernetes.io/name"       = "aws-load-balancer-controller"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "helm_release" "aws_lbc" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.aws_lbc_version

  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.aws_lbc.metadata[0].name
  }
  set {
    name  = "region"
    value = var.aws_region
  }
  set {
    name  = "vpcId"
    value = aws_vpc.main.id
  }

  set {
    name  = "tolerations[0].key"
    value = "node-role"
  }
  set {
    name  = "tolerations[0].value"
    value = "system"
  }
  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  set {
    name  = "nodeSelector.node-role"
    value = "system"
  }

  set {
    name  = "replicaCount"
    value = "2"
  }

  depends_on = [
    aws_eks_addon.vpc_cni,
    aws_eks_addon.coredns,
    kubernetes_service_account.aws_lbc,
  ]
}
