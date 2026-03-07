data "aws_caller_identity" "current" {}

resource "aws_ecr_repository" "zephyr" {
  name                 = "zephyr-app-${var.environment}"
  image_tag_mutability = "IMMUTABLE"

  # Mirrors Pulumi's forceDelete = true — allows destroy even when images exist.
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Lifecycle policy: keep the 10 most recent images per tag prefix to control storage costs.
resource "aws_ecr_lifecycle_policy" "zephyr" {
  repository = aws_ecr_repository.zephyr.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
