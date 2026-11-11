data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# ---------------------------------------------------------------------------
# Foundation contract (docs/fase-3/CONTRATOS.md section 2).
# Never use terraform_remote_state between repositories.
# ---------------------------------------------------------------------------
data "aws_ssm_parameter" "vpc_id" {
  name = "/oficina/${var.environment}/network/vpc_id"
}

data "aws_ssm_parameter" "vpc_cidr" {
  name = "/oficina/${var.environment}/network/vpc_cidr"
}

data "aws_ssm_parameter" "public_subnet_ids" {
  name = "/oficina/${var.environment}/network/public_subnet_ids"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/oficina/${var.environment}/network/private_subnet_ids"
}

# Security group that grants RDS:3306 access. Attached to the EKS worker nodes.
data "aws_ssm_parameter" "db_client_sg_id" {
  name = "/oficina/${var.environment}/db/client_sg_id"
}
