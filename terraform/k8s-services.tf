# ── Internal ClusterIP services ───────────────────────────────────────────────

resource "kubernetes_service" "assets" {
  metadata {
    name      = "assets"
    namespace = kubernetes_namespace.assets.metadata[0].name
    labels    = local.component_labels.assets
  }

  spec {
    selector = local.component_labels.assets
    type     = "ClusterIP"

    port {
      name        = "http"
      port        = 80
      protocol    = "TCP"
      target_port = "http"
    }
  }
}

resource "kubernetes_service" "carts" {
  metadata {
    name      = "carts"
    namespace = kubernetes_namespace.carts.metadata[0].name
    labels    = local.component_labels.carts
  }

  spec {
    selector = local.component_labels.carts
    type     = "ClusterIP"

    port {
      name        = "http"
      port        = 80
      protocol    = "TCP"
      target_port = "http"
    }
  }
}

resource "kubernetes_service" "carts_dynamodb" {
  metadata {
    name      = "carts-dynamodb"
    namespace = kubernetes_namespace.carts.metadata[0].name
    labels    = local.component_labels.carts_db
  }

  spec {
    selector = local.component_labels.carts_db
    type     = "ClusterIP"

    port {
      name        = "dynamodb"
      port        = 8000
      protocol    = "TCP"
      target_port = "dynamodb"
    }
  }
}

resource "kubernetes_service" "catalog" {
  metadata {
    name      = "catalog"
    namespace = kubernetes_namespace.catalog.metadata[0].name
    labels    = local.component_labels.catalog
  }

  spec {
    selector = local.component_labels.catalog
    type     = "ClusterIP"

    port {
      name        = "http"
      port        = 80
      protocol    = "TCP"
      target_port = "http"
    }
  }
}

resource "kubernetes_service" "checkout" {
  metadata {
    name      = "checkout"
    namespace = kubernetes_namespace.checkout.metadata[0].name
    labels    = local.component_labels.checkout
  }

  spec {
    selector = local.component_labels.checkout
    type     = "ClusterIP"

    port {
      name        = "http"
      port        = 80
      protocol    = "TCP"
      target_port = "http"
    }
  }
}

resource "kubernetes_service" "checkout_redis" {
  metadata {
    name      = "checkout-redis"
    namespace = kubernetes_namespace.checkout.metadata[0].name
    labels    = local.component_labels.checkout_db
  }

  spec {
    selector = local.component_labels.checkout_db
    type     = "ClusterIP"

    port {
      name        = "redis"
      port        = 6379
      protocol    = "TCP"
      target_port = "redis"
    }
  }
}

resource "kubernetes_service" "orders" {
  metadata {
    name      = "orders"
    namespace = kubernetes_namespace.orders.metadata[0].name
    labels    = local.component_labels.orders
  }

  spec {
    selector = local.component_labels.orders
    type     = "ClusterIP"

    port {
      name        = "http"
      port        = 80
      protocol    = "TCP"
      target_port = "http"
    }
  }
}

resource "kubernetes_service" "rabbitmq" {
  metadata {
    name      = "rabbitmq"
    namespace = kubernetes_namespace.rabbitmq.metadata[0].name
    labels    = local.component_labels.rabbitmq
  }

  spec {
    selector = local.component_labels.rabbitmq
    type     = "ClusterIP"

    port {
      name        = "amqp"
      port        = 5672
      protocol    = "TCP"
      target_port = "amqp"
    }

    port {
      name        = "http"
      port        = 15672
      protocol    = "TCP"
      target_port = "http"
    }
  }
}

resource "kubernetes_service" "ui" {
  metadata {
    name      = "ui"
    namespace = kubernetes_namespace.ui.metadata[0].name
    labels    = local.component_labels.ui
  }

  spec {
    selector = local.component_labels.ui
    type     = "ClusterIP"

    port {
      name        = "http"
      port        = 80
      protocol    = "TCP"
      target_port = "http"
    }
  }
}

# ── External LoadBalancer for UI ──────────────────────────────────────────────
# Equivalent of Pulumi's uiLbService. The DNS name appears in outputs.tf.

resource "kubernetes_service" "ui_lb" {
  metadata {
    name      = "ui-lb"
    namespace = kubernetes_namespace.ui.metadata[0].name
    labels    = local.component_labels.ui
  }

  spec {
    selector = local.component_labels.ui
    type     = "LoadBalancer"

    port {
      name        = "http"
      port        = 80
      protocol    = "TCP"
      target_port = "http"
    }
  }
}
