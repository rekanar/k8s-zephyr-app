output "ecr_repository_url" {
  description = "URL of the ECR repository used for locally built images."
  value       = aws_ecr_repository.zephyr.repository_url
}

output "assets_image_uri" {
  description = "Full URI of the built assets image."
  value       = local.assets_image_uri
}

output "catalog_image_uri" {
  description = "Full URI of the built catalog image."
  value       = local.catalog_image_uri
}

output "ui_image_uri" {
  description = "Full URI of the built UI image."
  value       = local.ui_image_uri
}

output "ui_load_balancer_hostname" {
  description = "External hostname of the UI load balancer. Use this in your browser (http://<hostname>)."
  value       = try(
    kubernetes_service.ui_lb.status[0].load_balancer[0].ingress[0].hostname,
    "pending — load balancer not yet assigned"
  )
}
