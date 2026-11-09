locals {
  name_prefix  = "oficina-${var.environment}"
  cluster_name = "${local.name_prefix}-eks"
  repo_name    = "oficina-infra-k8s" # old name of oficina-infra-cluster; changing it rolls every node (tags reach the launch template)

  # Foundation layer (oficina-infra-fundacao) is consumed exclusively through SSM.
  vpc_id             = data.aws_ssm_parameter.vpc_id.value
  vpc_cidr           = data.aws_ssm_parameter.vpc_cidr.value
  public_subnet_ids  = split(",", data.aws_ssm_parameter.public_subnet_ids.value)
  private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
  db_client_sg_id    = data.aws_ssm_parameter.db_client_sg_id.value
  db_secret_arn      = data.aws_ssm_parameter.db_secret_arn.value
  auth_secret_arn    = data.aws_ssm_parameter.auth_secret_arn.value

  account_id = data.aws_caller_identity.current.account_id

  # ADR-010: no NAT gateway in this challenge, so worker nodes live in the public
  # subnets and reach ECR/EKS/Secrets Manager through the Internet Gateway.
  node_subnet_ids = local.public_subnet_ids

  app_namespaces = {
    hml  = "oficina-hml"
    prod = "oficina-prod"
  }
  app_namespace = local.app_namespaces[var.environment]

  # Kubernetes group carried by the application pipeline (see eks.tf access entry).
  app_deployer_group = "oficina-app-deployers"

  eso_namespace       = "external-secrets"
  eso_service_account = "external-secrets"

  tags = {
    Project     = "oficina-mecanica"
    Environment = var.environment
    ManagedBy   = "terraform"
    Repo        = local.repo_name
  }
}
