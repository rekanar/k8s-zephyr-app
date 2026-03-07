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
