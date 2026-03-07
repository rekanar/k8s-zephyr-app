# Equivalent of Pulumi's catalogDbSecret and ordersDbSecret.
# The kubernetes_secret resource accepts plaintext values; the provider
# handles base64 encoding when writing to the Kubernetes API.

locals {
  catalog_connection_string = "${var.catalog_db_endpoint}:3306"
  orders_connection_string  = "jdbc:mariadb://${var.orders_db_endpoint}:3306/orders"
}

resource "kubernetes_secret" "catalog_db" {
  metadata {
    name      = "catalog-db"
    namespace = kubernetes_namespace.catalog.metadata[0].name
    labels    = local.component_labels.catalog
  }

  type = "Opaque"

  data = {
    name     = "catalog"
    username = "catalog_master"
    password = var.catalog_db_password
    endpoint = local.catalog_connection_string
  }
}

# Carts DynamoDB Local credentials — kept in a Secret (not ConfigMap) to avoid
# exposing credential keys in plain sight. The local DynamoDB does not validate
# these values, but the pattern should mirror production practice.
resource "kubernetes_secret" "carts_dynamodb" {
  metadata {
    name      = "carts-dynamodb"
    namespace = kubernetes_namespace.carts.metadata[0].name
    labels    = local.component_labels.carts
  }

  type = "Opaque"

  data = {
    AWS_ACCESS_KEY_ID     = "local-key"
    AWS_SECRET_ACCESS_KEY = "local-secret"
  }
}

resource "kubernetes_secret" "orders_db" {
  metadata {
    name      = "orders-db"
    namespace = kubernetes_namespace.orders.metadata[0].name
    labels    = local.component_labels.orders
  }

  type = "Opaque"

  data = {
    name     = "orders"
    username = "orders_master"
    password = var.orders_db_password
    url      = local.orders_connection_string
  }
}
