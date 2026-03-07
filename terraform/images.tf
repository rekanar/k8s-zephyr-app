# Equivalent of Pulumi's awsx.ecr.Image resources.
# Uses null_resource + local-exec to docker build and push each service image.
# Triggers on Dockerfile content changes or an explicit tag bump (var.app_image_tag).

locals {
  repo_root         = "${path.module}/.."
  assets_image_uri  = "${aws_ecr_repository.zephyr.repository_url}:assets-${var.app_image_tag}"
  catalog_image_uri = "${aws_ecr_repository.zephyr.repository_url}:catalog-${var.app_image_tag}"
  ui_image_uri      = "${aws_ecr_repository.zephyr.repository_url}:ui-${var.app_image_tag}"
}

# Log in to ECR before any image build.
resource "null_resource" "ecr_login" {
  triggers = {
    # Re-login whenever the repository URL changes (e.g. env switch).
    repo = aws_ecr_repository.zephyr.repository_url
  }

  provisioner "local-exec" {
    command = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.zephyr.repository_url}"
  }
}

# ── Assets image ──────────────────────────────────────────────────────────────

resource "null_resource" "assets_image" {
  depends_on = [null_resource.ecr_login]

  triggers = {
    image_tag  = var.app_image_tag
    dockerfile = filemd5("${local.repo_root}/src/assets/Dockerfile")
  }

  provisioner "local-exec" {
    command = <<-EOT
      DOCKER_BUILDKIT=1 docker build \
        --platform linux/amd64 \
        -f ${local.repo_root}/src/assets/Dockerfile \
        -t ${local.assets_image_uri} \
        ${local.repo_root}/src/assets \
      && docker push ${local.assets_image_uri}
    EOT
  }
}

# ── Catalog image ─────────────────────────────────────────────────────────────

resource "null_resource" "catalog_image" {
  depends_on = [null_resource.ecr_login]

  triggers = {
    image_tag  = var.app_image_tag
    dockerfile = filemd5("${local.repo_root}/src/catalog/Dockerfile")
  }

  provisioner "local-exec" {
    command = <<-EOT
      DOCKER_BUILDKIT=1 docker build \
        --platform linux/amd64 \
        -f ${local.repo_root}/src/catalog/Dockerfile \
        -t ${local.catalog_image_uri} \
        ${local.repo_root}/src/catalog \
      && docker push ${local.catalog_image_uri}
    EOT
  }
}

# ── UI image ──────────────────────────────────────────────────────────────────
# Mirrors Pulumi: uses images/java17/Dockerfile with build context src/ui
# and a JAR_PATH build arg.

resource "null_resource" "ui_image" {
  depends_on = [null_resource.ecr_login]

  triggers = {
    image_tag  = var.app_image_tag
    dockerfile = filemd5("${local.repo_root}/images/java17/Dockerfile")
  }

  provisioner "local-exec" {
    command = <<-EOT
      DOCKER_BUILDKIT=1 docker build \
        --platform linux/amd64 \
        -f ${local.repo_root}/images/java17/Dockerfile \
        --build-arg JAR_PATH=target/ui-0.0.1-SNAPSHOT.jar \
        -t ${local.ui_image_uri} \
        ${local.repo_root}/src/ui \
      && docker push ${local.ui_image_uri}
    EOT
  }
}
