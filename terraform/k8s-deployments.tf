# ── Assets ────────────────────────────────────────────────────────────────────

resource "kubernetes_deployment" "assets" {
  depends_on = [null_resource.assets_image]

  metadata {
    name      = "assets"
    namespace = kubernetes_namespace.assets.metadata[0].name
    labels    = local.component_labels.assets
  }

  spec {
    replicas = 1

    selector {
      match_labels = local.component_labels.assets
    }

    template {
      metadata {
        labels = local.component_labels.assets
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/path"   = "/metrics"
          "prometheus.io/port"   = "8080"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.assets.metadata[0].name

        container {
          name              = "assets"
          image             = local.assets_image_uri
          image_pull_policy = "IfNotPresent"

          env_from {
            config_map_ref {
              name = kubernetes_config_map.assets.metadata[0].name
            }
          }

          port {
            name           = "http"
            container_port = 8080
            protocol       = "TCP"
          }

          resources {
            limits   = { memory = "128Mi" }
            requests = { cpu = "128m", memory = "128Mi" }
          }

          liveness_probe {
            http_get {
              path = "/health.html"
              port = 8080
            }
            initial_delay_seconds = 30
            period_seconds        = 3
          }

          security_context {
            capabilities {
              drop = ["ALL"]
            }
            read_only_root_filesystem = false
          }

          volume_mount {
            name       = "tmp-volume"
            mount_path = "/tmp"
          }
        }

        volume {
          name = "tmp-volume"
          empty_dir {
            medium = "Memory"
          }
        }
      }
    }
  }
}

# ── Carts ─────────────────────────────────────────────────────────────────────

resource "kubernetes_deployment" "carts" {
  metadata {
    name      = "carts"
    namespace = kubernetes_namespace.carts.metadata[0].name
    labels    = local.component_labels.carts
  }

  spec {
    replicas = 1

    selector {
      match_labels = local.component_labels.carts
    }

    template {
      metadata {
        labels = local.component_labels.carts
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/path"   = "/actuator/prometheus"
          "prometheus.io/port"   = "8080"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.carts.metadata[0].name

        security_context {
          fs_group = 1000
        }

        container {
          name              = "carts"
          image             = "public.ecr.aws/aws-containers/retail-store-sample-cart:0.2.0"
          image_pull_policy = "IfNotPresent"

          env {
            name  = "JAVA_OPTS"
            value = "-XX:MaxRAMPercentage=75.0 -Djava.security.egd=file:/dev/urandom"
          }

          env {
            name  = "SPRING_PROFILES_ACTIVE"
            value = "dynamodb"
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.carts.metadata[0].name
            }
          }

          port {
            name           = "http"
            container_port = 8080
            protocol       = "TCP"
          }

          resources {
            limits   = { memory = "512Mi" }
            requests = { cpu = "128m", memory = "512Mi" }
          }

          liveness_probe {
            http_get {
              path = "/actuator/health/liveness"
              port = 8080
            }
            initial_delay_seconds = 45
            period_seconds        = 3
          }

          security_context {
            capabilities {
              drop = ["ALL"]
            }
            read_only_root_filesystem = true
            run_as_non_root           = true
            run_as_user               = 1000
          }

          volume_mount {
            name       = "tmp-volume"
            mount_path = "/tmp"
          }
        }

        volume {
          name = "tmp-volume"
          empty_dir {
            medium = "Memory"
          }
        }
      }
    }
  }
}

# ── Carts DynamoDB (local) ────────────────────────────────────────────────────

resource "kubernetes_deployment" "carts_dynamodb" {
  metadata {
    name      = "carts-dynamodb"
    namespace = kubernetes_namespace.carts.metadata[0].name
    labels    = local.component_labels.carts_db
  }

  spec {
    replicas = 1

    selector {
      match_labels = local.component_labels.carts_db
    }

    template {
      metadata {
        labels = local.component_labels.carts_db
      }

      spec {
        container {
          name              = "dynamodb"
          image             = "amazon/dynamodb-local:1.13.1"
          image_pull_policy = "IfNotPresent"

          port {
            name           = "dynamodb"
            container_port = 8000
            protocol       = "TCP"
          }
        }
      }
    }
  }
}

# ── Catalog ───────────────────────────────────────────────────────────────────

resource "kubernetes_deployment" "catalog" {
  depends_on = [null_resource.catalog_image]

  metadata {
    name      = "catalog"
    namespace = kubernetes_namespace.catalog.metadata[0].name
    labels    = local.component_labels.catalog
  }

  spec {
    replicas = 1

    selector {
      match_labels = local.component_labels.catalog
    }

    template {
      metadata {
        labels = local.component_labels.catalog
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/path"   = "/metrics"
          "prometheus.io/port"   = "8080"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.catalog.metadata[0].name

        security_context {
          fs_group = 1000
        }

        container {
          name              = "catalog"
          image             = local.catalog_image_uri
          image_pull_policy = "IfNotPresent"

          env {
            name = "DB_ENDPOINT"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.catalog_db.metadata[0].name
                key  = "endpoint"
              }
            }
          }

          env {
            name = "DB_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.catalog_db.metadata[0].name
                key  = "username"
              }
            }
          }

          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.catalog_db.metadata[0].name
                key  = "password"
              }
            }
          }

          env {
            name = "DB_READ_ENDPOINT"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.catalog_db.metadata[0].name
                key  = "endpoint"
              }
            }
          }

          env {
            name = "DB_NAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.catalog_db.metadata[0].name
                key  = "name"
              }
            }
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.catalog.metadata[0].name
            }
          }

          port {
            name           = "http"
            container_port = 8080
            protocol       = "TCP"
          }

          resources {
            limits   = { memory = "256Mi" }
            requests = { cpu = "128m", memory = "256Mi" }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 30
            period_seconds        = 3
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            period_seconds    = 5
            success_threshold = 3
          }

          security_context {
            capabilities {
              drop = ["ALL"]
            }
            read_only_root_filesystem = true
            run_as_non_root           = true
            run_as_user               = 1000
          }

          volume_mount {
            name       = "tmp-volume"
            mount_path = "/tmp"
          }
        }

        volume {
          name = "tmp-volume"
          empty_dir {
            medium = "Memory"
          }
        }
      }
    }
  }
}

# ── Checkout ──────────────────────────────────────────────────────────────────

resource "kubernetes_deployment" "checkout" {
  metadata {
    name      = "checkout"
    namespace = kubernetes_namespace.checkout.metadata[0].name
    labels    = local.component_labels.checkout
  }

  spec {
    replicas = 1

    selector {
      match_labels = local.component_labels.checkout
    }

    template {
      metadata {
        labels = local.component_labels.checkout
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/path"   = "/metrics"
          "prometheus.io/port"   = "8080"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.checkout.metadata[0].name

        security_context {
          fs_group = 1000
        }

        container {
          name              = "checkout"
          image             = "public.ecr.aws/aws-containers/retail-store-sample-checkout:0.2.0"
          image_pull_policy = "IfNotPresent"

          env_from {
            config_map_ref {
              name = kubernetes_config_map.checkout.metadata[0].name
            }
          }

          port {
            name           = "http"
            container_port = 8080
            protocol       = "TCP"
          }

          resources {
            limits   = { memory = "256Mi" }
            requests = { cpu = "128m", memory = "256Mi" }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 30
            period_seconds        = 3
          }

          security_context {
            capabilities {
              drop = ["ALL"]
            }
            read_only_root_filesystem = true
            run_as_non_root           = true
            run_as_user               = 1000
          }

          volume_mount {
            name       = "tmp-volume"
            mount_path = "/tmp"
          }
        }

        volume {
          name = "tmp-volume"
          empty_dir {
            medium = "Memory"
          }
        }
      }
    }
  }
}

# ── Checkout Redis ────────────────────────────────────────────────────────────

resource "kubernetes_deployment" "checkout_redis" {
  metadata {
    name      = "checkout-redis"
    namespace = kubernetes_namespace.checkout.metadata[0].name
    labels    = local.component_labels.checkout_db
  }

  spec {
    replicas = 1

    selector {
      match_labels = local.component_labels.checkout_db
    }

    template {
      metadata {
        labels = local.component_labels.checkout_db
      }

      spec {
        container {
          name              = "redis"
          image             = "redis:6.0-alpine"
          image_pull_policy = "IfNotPresent"

          port {
            name           = "redis"
            container_port = 6379
            protocol       = "TCP"
          }
        }
      }
    }
  }
}

# ── Orders ────────────────────────────────────────────────────────────────────

resource "kubernetes_deployment" "orders" {
  metadata {
    name      = "orders"
    namespace = kubernetes_namespace.orders.metadata[0].name
    labels    = local.component_labels.orders
  }

  spec {
    replicas = 1

    selector {
      match_labels = local.component_labels.orders
    }

    template {
      metadata {
        labels = local.component_labels.orders
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/path"   = "/actuator/prometheus"
          "prometheus.io/port"   = "8080"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.orders.metadata[0].name

        security_context {
          fs_group = 1000
        }

        container {
          name              = "orders"
          image             = "public.ecr.aws/aws-containers/retail-store-sample-orders:0.2.0"
          image_pull_policy = "IfNotPresent"

          env {
            name  = "JAVA_OPTS"
            value = "-XX:MaxRAMPercentage=75.0 -Djava.security.egd=file:/dev/urandom"
          }

          env {
            name = "SPRING_DATASOURCE_WRITER_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.orders_db.metadata[0].name
                key  = "url"
              }
            }
          }

          env {
            name = "SPRING_DATASOURCE_WRITER_USERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.orders_db.metadata[0].name
                key  = "username"
              }
            }
          }

          env {
            name = "SPRING_DATASOURCE_WRITER_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.orders_db.metadata[0].name
                key  = "password"
              }
            }
          }

          env {
            name = "SPRING_DATASOURCE_READER_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.orders_db.metadata[0].name
                key  = "url"
              }
            }
          }

          env {
            name = "SPRING_DATASOURCE_READER_USERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.orders_db.metadata[0].name
                key  = "username"
              }
            }
          }

          env {
            name = "SPRING_DATASOURCE_READER_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.orders_db.metadata[0].name
                key  = "password"
              }
            }
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.orders.metadata[0].name
            }
          }

          port {
            name           = "http"
            container_port = 8080
            protocol       = "TCP"
          }

          resources {
            limits   = { memory = "512Mi" }
            requests = { cpu = "128m", memory = "512Mi" }
          }

          liveness_probe {
            http_get {
              path = "/actuator/health/liveness"
              port = 8080
            }
            initial_delay_seconds = 45
            period_seconds        = 3
          }

          readiness_probe {
            http_get {
              path = "/actuator/health/liveness"
              port = 8080
            }
            period_seconds    = 5
            success_threshold = 3
          }

          security_context {
            capabilities {
              drop = ["ALL"]
            }
            read_only_root_filesystem = true
            run_as_non_root           = true
            run_as_user               = 1000
          }

          volume_mount {
            name       = "tmp-volume"
            mount_path = "/tmp"
          }
        }

        volume {
          name = "tmp-volume"
          empty_dir {
            medium = "Memory"
          }
        }
      }
    }
  }
}

# ── RabbitMQ ──────────────────────────────────────────────────────────────────

resource "kubernetes_deployment" "rabbitmq" {
  metadata {
    name      = "rabbitmq"
    namespace = kubernetes_namespace.rabbitmq.metadata[0].name
    labels    = local.component_labels.rabbitmq
  }

  spec {
    replicas = 1

    selector {
      match_labels = local.component_labels.rabbitmq
    }

    template {
      metadata {
        labels = local.component_labels.rabbitmq
      }

      spec {
        service_account_name = kubernetes_service_account.rabbitmq.metadata[0].name

        container {
          name              = "rabbitmq"
          image             = "rabbitmq:3-management"
          image_pull_policy = "IfNotPresent"

          port {
            name           = "amqp"
            container_port = 5672
            protocol       = "TCP"
          }

          port {
            name           = "http"
            container_port = 15672
            protocol       = "TCP"
          }
        }
      }
    }
  }
}

# ── UI ────────────────────────────────────────────────────────────────────────

resource "kubernetes_deployment" "ui" {
  depends_on = [null_resource.ui_image]

  metadata {
    name      = "ui"
    namespace = kubernetes_namespace.ui.metadata[0].name
    labels    = local.component_labels.ui
  }

  spec {
    replicas = 1

    selector {
      match_labels = local.component_labels.ui
    }

    template {
      metadata {
        labels = local.component_labels.ui
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/path"   = "/actuator/prometheus"
          "prometheus.io/port"   = "8080"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.ui.metadata[0].name

        security_context {
          fs_group = 1000
        }

        container {
          name              = "ui"
          image             = local.ui_image_uri
          image_pull_policy = "IfNotPresent"

          env {
            name  = "JAVA_OPTS"
            value = "-XX:MaxRAMPercentage=75.0 -Djava.security.egd=file:/dev/urandom"
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.ui.metadata[0].name
            }
          }

          port {
            name           = "http"
            container_port = 8080
            protocol       = "TCP"
          }

          resources {
            limits   = { memory = "512Mi" }
            requests = { cpu = "128m", memory = "512Mi" }
          }

          liveness_probe {
            http_get {
              path = "/actuator/health/liveness"
              port = 8080
            }
            initial_delay_seconds = 45
            period_seconds        = 20
          }

          security_context {
            capabilities {
              add  = ["NET_BIND_SERVICE"]
              drop = ["ALL"]
            }
            read_only_root_filesystem = true
            run_as_non_root           = true
            run_as_user               = 1000
          }

          volume_mount {
            name       = "tmp-volume"
            mount_path = "/tmp"
          }
        }

        volume {
          name = "tmp-volume"
          empty_dir {
            medium = "Memory"
          }
        }
      }
    }
  }
}
