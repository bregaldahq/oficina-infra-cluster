module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = local.vpc_id
  subnet_ids = local.node_subnet_ids

  # Public API endpoint (there is no bastion and no NAT), restricted by CIDR.
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  cluster_endpoint_private_access      = true

  enable_cluster_creator_admin_permissions = true
  authentication_mode                      = "API_AND_CONFIG_MAP"

  # EKS authorisation is NOT IAM authorisation. The application's CI role can hold
  # AdministratorAccess in IAM and still get "the server has asked for the client to
  # provide credentials" from kubectl: the cluster only trusts principals that have an
  # explicit access entry. Only the creator (this stack's role) gets one automatically.
  #
  # Scoped to the two application namespaces instead of the whole cluster: the app
  # pipeline deploys workloads, it has no business touching kube-system.
  # Fase 4: o pipeline de cada microsservico entra com o mesmo acesso do da
  # aplicacao (app_ci e o do servico de OS).
  access_entries = {
    for name, role_arn in merge({ app_ci = var.app_ci_role_arn }, var.service_ci_role_arns) : name => {
      principal_arn = role_arn
      type          = "STANDARD"

      # Mapped to a Kubernetes group so custom RBAC can be bound to it below:
      # the managed EKS policies cover core resources only, not CRDs.
      kubernetes_groups = [local.app_deployer_group]

      policy_associations = {
        namespace_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
          access_scope = {
            type       = "namespace"
            namespaces = values(local.app_namespaces)
          }
        }
      }
    }
  }

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}

    # Fase 4: tres servicos com api e worker nao cabem no limite de pods por ENI
    # de dois t3.medium (17 cada). Prefix delegation leva o limite a 110 por
    # node sem node a mais. before_compute: o addon precisa estar configurado
    # antes de os nodes nascerem, senao eles sobem com o limite antigo.
    vpc-cni = {
      before_compute = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  eks_managed_node_group_defaults = {
    ami_type = "AL2023_x86_64_STANDARD"
  }

  eks_managed_node_groups = {
    default = {
      name = "${local.name_prefix}-ng"

      instance_types = var.node_instance_types
      capacity_type  = var.capacity_type

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      subnet_ids = local.node_subnet_ids

      # ADR-010: no NAT gateway, so nodes need a public IP to pull images and to
      # reach the EKS/ECR/Secrets Manager endpoints.
      network_interfaces = [
        {
          associate_public_ip_address = true
          delete_on_termination       = true
          device_index                = 0
        }
      ]

      block_device_mappings = {
        root = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = var.node_disk_size
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      # Grants the pods running on this node RDS:3306 access (contract section 2).
      vpc_security_group_ids = [local.db_client_sg_id]

      labels = {
        workload = "oficina-api"
      }

      tags = local.tags
    }
  }

  tags = local.tags
}
