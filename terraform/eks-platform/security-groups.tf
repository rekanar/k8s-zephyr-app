# =============================================================================
# Security Groups — principle of least privilege
#
# EKS creates its own cluster SG automatically; we create additional SGs
# for fine-grained control:
#
#   sg_cluster_extra  — attached to the cluster ENIs (source for node rules)
#   sg_nodes          — attached to all managed node groups
#
# Node-to-node and node-to-control-plane rules follow the ports documented at
# https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html
# =============================================================================

# ── Extra cluster SG (attached alongside the EKS-managed cluster SG) ──────────

resource "aws_security_group" "cluster_extra" {
  name        = "${var.cluster_name}-cluster-extra"
  description = "Additional rules for the EKS cluster API endpoint"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.cluster_name}-cluster-extra" }
}

# Allow nodes to reach the API server
resource "aws_security_group_rule" "cluster_ingress_from_nodes" {
  security_group_id        = aws_security_group.cluster_extra.id
  type                     = "ingress"
  description              = "Nodes → API server (HTTPS)"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.nodes.id
}

resource "aws_security_group_rule" "cluster_egress_all" {
  security_group_id = aws_security_group.cluster_extra.id
  type              = "egress"
  description       = "Allow all outbound from cluster"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# ── Node security group ───────────────────────────────────────────────────────

resource "aws_security_group" "nodes" {
  name        = "${var.cluster_name}-nodes"
  description = "EKS managed node groups"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name                                        = "${var.cluster_name}-nodes"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

# Nodes talk to each other on all ports (intra-cluster traffic)
resource "aws_security_group_rule" "nodes_ingress_self" {
  security_group_id        = aws_security_group.nodes.id
  type                     = "ingress"
  description              = "Node → node (all protocols)"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.nodes.id
}

# API server pushes webhooks and metrics to kubelets on nodes (port 10250)
resource "aws_security_group_rule" "nodes_ingress_from_cluster" {
  security_group_id        = aws_security_group.nodes.id
  type                     = "ingress"
  description              = "Control plane → kubelet (10250)"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster_extra.id
}

# NodePort services (30000-32767) — only open if you use NodePort type services
resource "aws_security_group_rule" "nodes_ingress_nodeport" {
  security_group_id        = aws_security_group.nodes.id
  type                     = "ingress"
  description              = "NodePort services"
  from_port                = 30000
  to_port                  = 32767
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.nodes.id
}

# All outbound (nodes pull images, call AWS APIs, reach the internet)
resource "aws_security_group_rule" "nodes_egress_all" {
  security_group_id = aws_security_group.nodes.id
  type              = "egress"
  description       = "All outbound from nodes"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# ── Bastion / jump-host SG (optional — uncomment if needed) ──────────────────
#
# resource "aws_security_group" "bastion" {
#   name        = "${var.cluster_name}-bastion"
#   description = "SSH bastion for cluster debugging"
#   vpc_id      = aws_vpc.main.id
#
#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["203.0.113.0/32"] # your IP only
#   }
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }
