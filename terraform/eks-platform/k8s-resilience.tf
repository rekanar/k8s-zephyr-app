# =============================================================================
# Kubernetes Resilience — Rolling Updates, Crash Loop Guards, HPA, PDB
#
# This file wires together four layers of resilience:
#
# 1. ROLLING UPDATES
#    Each Deployment uses RollingUpdate strategy with:
#      maxUnavailable = 0   — never reduce capacity during rollout
#      maxSurge       = 1   — spin up one extra pod at a time
#    Combined with node-level update_config.max_unavailable = 1 in
#    node-groups.tf, this ensures zero-downtime deploys at both layers.
#
# 2. CRASH LOOP PREVENTION
#    Probes: liveness evicts a stuck pod; readiness removes it from LB traffic.
#    Resource limits: OOM kills are bounded — a runaway pod can't consume all
#    node memory and cause other pods to be killed.
#    restartPolicy: Always (default) with exponential back-off (built into K8s).
#
# 3. HORIZONTAL POD AUTOSCALER (HPA)
#    Scales pod replicas based on CPU/memory.  Interacts with Cluster Autoscaler:
#    HPA adds pods → CA adds nodes.
#
# 4. POD DISRUPTION BUDGETS (PDB)
#    Guarantees a minimum number of pods stay Running during:
#      ✓ Node rolling updates
#      ✓ Cluster Autoscaler scale-in
#      ✓ kubectl drain
# =============================================================================

# ── Deployment rolling update strategy example ─────────────────────────────────
# Use this strategy block in every Deployment in the app terraform stack.
#
# strategy:
#   type: RollingUpdate
#   rollingUpdate:
#     maxUnavailable: 0    ← never go below desired capacity
#     maxSurge: 1          ← allow 1 extra pod during rollout
#
# The resources below add HPA and PDB on top of the existing Deployments
# (defined in terraform/k8s-deployments.tf).

# ── HPA — Horizontal Pod Autoscaler ──────────────────────────────────────────
# Requires the metrics-server add-on (deployed below).

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server"
  chart      = "metrics-server"
  version    = "3.12.1"

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

  depends_on = [aws_eks_node_group.system]
}

# ── Network Policy — default deny (zero-trust baseline) ────────────────────────
# Install Calico or use VPC CNI network policies for enforcement.
# These policies are rendered as K8s NetworkPolicy objects; the CNI must
# support enforcement (vanilla vpc-cni with network policy mode enabled, or Calico).

resource "kubernetes_network_policy" "default_deny_all" {
  for_each = toset(["assets", "catalog", "carts", "checkout", "orders", "rabbitmq", "ui"])

  metadata {
    name      = "default-deny-all"
    namespace = each.key
  }

  spec {
    # Selects ALL pods in the namespace
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
    # No ingress/egress rules = deny all
  }

  depends_on = [aws_eks_addon.vpc_cni]
}

# Allow each namespace to reach its own pods (intra-namespace)
resource "kubernetes_network_policy" "allow_intra_namespace" {
  for_each = toset(["assets", "catalog", "carts", "checkout", "orders", "rabbitmq", "ui"])

  metadata {
    name      = "allow-intra-namespace"
    namespace = each.key
  }

  spec {
    pod_selector {}

    ingress {
      from {
        pod_selector {}
      }
    }

    egress {
      to {
        pod_selector {}
      }
    }

    policy_types = ["Ingress", "Egress"]
  }

  depends_on = [kubernetes_network_policy.default_deny_all]
}

# Allow all namespaces to reach kube-dns (CoreDNS on port 53)
resource "kubernetes_network_policy" "allow_dns" {
  for_each = toset(["assets", "catalog", "carts", "checkout", "orders", "rabbitmq", "ui"])

  metadata {
    name      = "allow-dns"
    namespace = each.key
  }

  spec {
    pod_selector {}

    egress {
      to {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = "kube-system" }
        }
        pod_selector {
          match_labels = { "k8s-app" = "kube-dns" }
        }
      }
      ports {
        port     = "53"
        protocol = "UDP"
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
    }

    policy_types = ["Egress"]
  }

  depends_on = [kubernetes_network_policy.default_deny_all]
}

# ── PodDisruptionBudgets ──────────────────────────────────────────────────────
# Prevents zero-pod situations during node drains / CA scale-in.
# min_available = 1 means at least 1 pod must remain Running at all times.

locals {
  pdb_targets = {
    assets   = { namespace = "assets",   app_label = "assets" }
    carts    = { namespace = "carts",    app_label = "carts" }
    catalog  = { namespace = "catalog",  app_label = "catalog" }
    checkout = { namespace = "checkout", app_label = "checkout" }
    orders   = { namespace = "orders",   app_label = "orders" }
    ui       = { namespace = "ui",       app_label = "ui" }
  }
}

resource "kubernetes_pod_disruption_budget_v1" "app" {
  for_each = local.pdb_targets

  metadata {
    name      = each.key
    namespace = each.value.namespace
  }

  spec {
    min_available = "1" # keep at least 1 pod alive during disruptions

    selector {
      match_labels = {
        "app.kubernetes.io/component" = each.value.app_label
        "app.kubernetes.io/name"      = "zephyr-app"
      }
    }
  }
}

# ── HPA — scale catalog and ui based on CPU ───────────────────────────────────

resource "kubernetes_horizontal_pod_autoscaler_v2" "catalog" {
  metadata {
    name      = "catalog"
    namespace = "catalog"
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "catalog"
    }

    min_replicas = 2   # always keep 2 so PDB can protect during rollout
    max_replicas = 8

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 60
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }

    behavior {
      scale_up {
        stabilization_window_seconds = 60
        select_policy                = "Max"
        policy {
          type           = "Pods"
          value          = 2
          period_seconds = 60
        }
      }
      scale_down {
        stabilization_window_seconds = 300 # don't scale down for 5 min after a spike
        select_policy                = "Min"
        policy {
          type           = "Pods"
          value          = 1
          period_seconds = 60
        }
      }
    }
  }

  depends_on = [helm_release.metrics_server]
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "ui" {
  metadata {
    name      = "ui"
    namespace = "ui"
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "ui"
    }

    min_replicas = 2
    max_replicas = 6

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 60
        }
      }
    }

    behavior {
      scale_up {
        stabilization_window_seconds = 60
        policy {
          type           = "Pods"
          value          = 1
          period_seconds = 30
        }
      }
      scale_down {
        stabilization_window_seconds = 300
        policy {
          type           = "Pods"
          value          = 1
          period_seconds = 60
        }
      }
    }
  }

  depends_on = [helm_release.metrics_server]
}

# ── Topology Spread Constraints ───────────────────────────────────────────────
# Applied via a MutatingWebhook or directly in deployment specs.
# Example patch — apply this after your Deployments exist.
# It spreads pods across zones so a single AZ failure doesn't kill all replicas.
#
# resource "kubernetes_manifest" "ui_topology_patch" {
#   manifest = {
#     apiVersion = "apps/v1"
#     kind       = "Deployment"
#     metadata   = { name = "ui", namespace = "ui" }
#     spec = {
#       template = {
#         spec = {
#           topologySpreadConstraints = [{
#             maxSkew           = 1
#             topologyKey       = "topology.kubernetes.io/zone"
#             whenUnsatisfiable = "DoNotSchedule"
#             labelSelector     = { matchLabels = { "app.kubernetes.io/component" = "ui" } }
#           }]
#         }
#       }
#     }
#   }
# }
