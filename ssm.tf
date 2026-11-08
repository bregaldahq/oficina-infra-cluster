# ---------------------------------------------------------------------------
# B10 - Published contract (CONTRATOS.md section 2). Parameter names are literal
# and consumed by oficina-gateway-auth and by the application repository.
# ---------------------------------------------------------------------------
resource "aws_ssm_parameter" "eks_cluster_name" {
  name  = "/oficina/${var.environment}/eks/cluster_name"
  type  = "String"
  value = module.eks.cluster_name
  tags  = local.tags
}

resource "aws_ssm_parameter" "eks_cluster_endpoint" {
  name  = "/oficina/${var.environment}/eks/cluster_endpoint"
  type  = "String"
  value = module.eks.cluster_endpoint
  tags  = local.tags
}

resource "aws_ssm_parameter" "eks_oidc_provider_arn" {
  name  = "/oficina/${var.environment}/eks/oidc_provider_arn"
  type  = "String"
  value = module.eks.oidc_provider_arn
  tags  = local.tags
}

resource "aws_ssm_parameter" "eks_node_security_group_id" {
  name  = "/oficina/${var.environment}/eks/node_security_group_id"
  type  = "String"
  value = module.eks.node_security_group_id
  tags  = local.tags
}

resource "aws_ssm_parameter" "ecr_repository_url" {
  name  = "/oficina/${var.environment}/ecr/repository_url"
  type  = "String"
  value = aws_ecr_repository.api.repository_url
  tags  = local.tags
}

resource "aws_ssm_parameter" "nlb_arn" {
  name  = "/oficina/${var.environment}/nlb/arn"
  type  = "String"
  value = aws_lb.internal.arn
  tags  = local.tags
}

resource "aws_ssm_parameter" "nlb_listener_arn" {
  name  = "/oficina/${var.environment}/nlb/listener_arn"
  type  = "String"
  value = aws_lb_listener.http.arn
  tags  = local.tags
}

# Extra parameter (outside CONTRATOS.md section 2, additive only): the app repo
# needs the target group ARN to write its TargetGroupBinding. See README.
resource "aws_ssm_parameter" "nlb_target_group_arn" {
  name  = "/oficina/${var.environment}/nlb/target_group_arn"
  type  = "String"
  value = aws_lb_target_group.api.arn
  tags  = local.tags
}

# Extra parameter (additive): namespace the app overlay deploys into.
resource "aws_ssm_parameter" "app_namespace" {
  name  = "/oficina/${var.environment}/eks/namespace"
  type  = "String"
  value = local.app_namespace
  tags  = local.tags
}
