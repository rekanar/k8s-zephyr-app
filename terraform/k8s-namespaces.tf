# Shared label sets — equivalent to Pulumi's per-component label objects.
# Centralised here so every other .tf file can reference locals.component_labels.<name>.
locals {
  common_labels = {
    "app.kubernetes.io/name"       = "zephyr-app"
    "app.kubernetes.io/managed-by" = "terraform"
  }

  component_labels = {
    assets      = merge(local.common_labels, { "app.kubernetes.io/component" = "assets" })
    carts       = merge(local.common_labels, { "app.kubernetes.io/component" = "carts" })
    carts_db    = merge(local.common_labels, { "app.kubernetes.io/component" = "carts-dynamodb" })
    catalog     = merge(local.common_labels, { "app.kubernetes.io/component" = "catalog" })
    checkout    = merge(local.common_labels, { "app.kubernetes.io/component" = "checkout" })
    checkout_db = merge(local.common_labels, { "app.kubernetes.io/component" = "checkout-redis" })
    orders      = merge(local.common_labels, { "app.kubernetes.io/component" = "orders" })
    rabbitmq    = merge(local.common_labels, { "app.kubernetes.io/component" = "rabbitmq" })
    ui          = merge(local.common_labels, { "app.kubernetes.io/component" = "ui" })
  }
}

# ── Namespaces ────────────────────────────────────────────────────────────────

resource "kubernetes_namespace" "assets" {
  metadata {
    name   = "assets"
    labels = local.component_labels.assets
  }
}

resource "kubernetes_namespace" "carts" {
  metadata {
    name   = "carts"
    labels = local.component_labels.carts
  }
}

resource "kubernetes_namespace" "catalog" {
  metadata {
    name   = "catalog"
    labels = local.component_labels.catalog
  }
}

resource "kubernetes_namespace" "checkout" {
  metadata {
    name   = "checkout"
    labels = local.component_labels.checkout
  }
}

resource "kubernetes_namespace" "orders" {
  metadata {
    name   = "orders"
    labels = local.component_labels.orders
  }
}

resource "kubernetes_namespace" "rabbitmq" {
  metadata {
    name   = "rabbitmq"
    labels = local.component_labels.rabbitmq
  }
}

resource "kubernetes_namespace" "ui" {
  metadata {
    name   = "ui"
    labels = local.component_labels.ui
  }
}

# ── Service Accounts ──────────────────────────────────────────────────────────

resource "kubernetes_service_account" "assets" {
  metadata {
    name      = "assets"
    namespace = kubernetes_namespace.assets.metadata[0].name
    labels    = local.component_labels.assets
  }
}

resource "kubernetes_service_account" "carts" {
  metadata {
    name      = "carts"
    namespace = kubernetes_namespace.carts.metadata[0].name
    labels    = local.component_labels.carts
  }
}

resource "kubernetes_service_account" "catalog" {
  metadata {
    name      = "catalog"
    namespace = kubernetes_namespace.catalog.metadata[0].name
    labels    = local.component_labels.catalog
  }
}

resource "kubernetes_service_account" "checkout" {
  metadata {
    name      = "checkout"
    namespace = kubernetes_namespace.checkout.metadata[0].name
    labels    = local.component_labels.checkout
  }
}

resource "kubernetes_service_account" "orders" {
  metadata {
    name      = "orders"
    namespace = kubernetes_namespace.orders.metadata[0].name
    labels    = local.component_labels.orders
  }
}

resource "kubernetes_service_account" "rabbitmq" {
  metadata {
    name      = "rabbitmq"
    namespace = kubernetes_namespace.rabbitmq.metadata[0].name
    labels    = local.component_labels.rabbitmq
  }
}

resource "kubernetes_service_account" "ui" {
  metadata {
    name      = "ui"
    namespace = kubernetes_namespace.ui.metadata[0].name
    labels    = local.component_labels.ui
  }
}
