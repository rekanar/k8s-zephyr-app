# =============================================================================
# KMS — Customer Managed Key for EKS secrets encryption
#
# EKS uses this key to encrypt Kubernetes Secrets stored in etcd at rest.
# Best practice: use a CMK so you control rotation and can audit all usage
# via CloudTrail.
# =============================================================================

resource "aws_kms_key" "eks_secrets" {
  description             = "EKS secrets encryption key for cluster ${var.cluster_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true # automatic annual rotation

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Allow root account full access (required)
      {
        Sid    = "RootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      # Allow EKS to use the key for envelope encryption
      {
        Sid    = "EKSSecretsEncryption"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      # Allow the EKS cluster IAM role to use the key
      {
        Sid    = "ClusterRoleAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.eks_cluster.arn
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant",
          "kms:ListGrants"
        ]
        Resource = "*"
      }
    ]
  })

  tags = { Name = "${var.cluster_name}-secrets-key" }
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${var.cluster_name}-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}

# Separate key for CloudWatch log group encryption
resource "aws_kms_key" "cloudwatch" {
  description             = "CloudWatch log encryption key for cluster ${var.cluster_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = { Name = "${var.cluster_name}-cloudwatch-key" }
}
