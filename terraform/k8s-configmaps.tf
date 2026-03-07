resource "kubernetes_config_map" "assets" {
  metadata {
    name      = "assets"
    namespace = kubernetes_namespace.assets.metadata[0].name
    labels    = local.component_labels.assets
  }

  data = {
    PORT = "8080"
  }
}

resource "kubernetes_config_map" "carts" {
  metadata {
    name      = "carts"
    namespace = kubernetes_namespace.carts.metadata[0].name
    labels    = local.component_labels.carts
  }

  data = {
    AWS_ACCESS_KEY_ID          = "key"
    AWS_SECRET_ACCESS_KEY      = "secret"
    CARTS_DYNAMODB_CREATETABLE = "true"
    CARTS_DYNAMODB_ENDPOINT    = "http://carts-dynamodb:8000"
    CARTS_DYNAMODB_TABLENAME   = "Items"
  }
}

# catalog has no data entries in the Pulumi source — kept as empty ConfigMap
# to preserve the resource for envFrom references in the Deployment.
resource "kubernetes_config_map" "catalog" {
  metadata {
    name      = "catalog"
    namespace = kubernetes_namespace.catalog.metadata[0].name
    labels    = local.component_labels.catalog
  }
}

resource "kubernetes_config_map" "checkout" {
  metadata {
    name      = "checkout"
    namespace = kubernetes_namespace.checkout.metadata[0].name
    labels    = local.component_labels.checkout
  }

  data = {
    ENDPOINTS_ORDERS = "http://orders.orders.svc:80"
    REDIS_URL        = "redis://checkout-redis:6379"
  }
}

resource "kubernetes_config_map" "orders" {
  metadata {
    name      = "orders"
    namespace = kubernetes_namespace.orders.metadata[0].name
    labels    = local.component_labels.orders
  }

  data = {
    SPRING_PROFILES_ACTIVE = "mysql,rabbitmq"
    SPRING_RABBITMQ_HOST   = "rabbitmq.rabbitmq.svc"
  }
}

# rabbitmq has no data entries — kept as empty ConfigMap.
resource "kubernetes_config_map" "rabbitmq" {
  metadata {
    name      = "rabbitmq"
    namespace = kubernetes_namespace.rabbitmq.metadata[0].name
    labels    = local.component_labels.rabbitmq
  }
}

resource "kubernetes_config_map" "ui" {
  metadata {
    name      = "ui"
    namespace = kubernetes_namespace.ui.metadata[0].name
    labels    = local.component_labels.ui
  }

  data = {
    ENDPOINTS_ASSETS   = "http://assets.assets.svc:80"
    ENDPOINTS_CARTS    = "http://carts.carts.svc:80"
    ENDPOINTS_CATALOG  = "http://catalog.catalog.svc:80"
    ENDPOINTS_CHECKOUT = "http://checkout.checkout.svc:80"
    ENDPOINTS_ORDERS   = "http://orders.orders.svc:80"
  }
}
