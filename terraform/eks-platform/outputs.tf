output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint URL."
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_cert" {
  description = "Base64-encoded cluster CA certificate (use base64decode() when passing to providers)."
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_version" {
  description = "Kubernetes version running on the cluster."
  value       = aws_eks_cluster.main.version
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC identity provider (for IRSA in downstream stacks)."
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC identity provider (without https://)."
  value       = local.oidc_provider_url
}

output "vpc_id" {
  description = "ID of the VPC that the cluster runs in."
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (where EKS nodes run)."
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (for load balancers)."
  value       = aws_subnet.public[*].id
}

output "node_role_arn" {
  description = "IAM role ARN attached to EKS nodes — pass to downstream IRSA trust policies."
  value       = aws_iam_role.node_group.arn
}

output "node_security_group_id" {
  description = "Security group ID for EKS nodes — allow ingress from your app load balancers."
  value       = aws_security_group.nodes.id
}

# kubeconfig for humans / CI pipelines.
# Write to a file with:  terraform output -raw kubeconfig > kubeconfig
output "kubeconfig" {
  description = "Rendered kubeconfig for kubectl access."
  sensitive   = true
  value       = <<-EOT
    apiVersion: v1
    kind: Config
    clusters:
    - cluster:
        certificate-authority-data: ${aws_eks_cluster.main.certificate_authority[0].data}
        server: ${aws_eks_cluster.main.endpoint}
      name: ${aws_eks_cluster.main.name}
    contexts:
    - context:
        cluster: ${aws_eks_cluster.main.name}
        user: ${aws_eks_cluster.main.name}-admin
      name: ${aws_eks_cluster.main.name}
    current-context: ${aws_eks_cluster.main.name}
    users:
    - name: ${aws_eks_cluster.main.name}-admin
      user:
        exec:
          apiVersion: client.authentication.k8s.io/v1beta1
          command: aws
          args:
          - eks
          - get-token
          - --cluster-name
          - ${aws_eks_cluster.main.name}
          - --region
          - ${var.aws_region}
  EOT
}
