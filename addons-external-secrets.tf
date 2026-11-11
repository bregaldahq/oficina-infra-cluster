# ---------------------------------------------------------------------------
# B5 - External Secrets Operator: IRSA restricted to the two secrets owned by
# oficina-infra-fundacao, the Helm release, and the ClusterSecretStore that the
# application ExternalSecret references.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "external_secrets" {
  statement {
    sid    = "ReadOficinaSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    # Fase 4: cada microsservico cria os proprios segredos sob oficina/<env>/
    # (docs/fase-4/CONTRATOS.md, secao 3), e este repo aplica antes deles. Por
    # isso o prefixo do ambiente, e nao uma lista de ARNs.
    resources = [
      "arn:${data.aws_partition.current.partition}:secretsmanager:${var.region}:${local.account_id}:secret:oficina/${var.environment}/*",
    ]
  }

  statement {
    sid       = "ListSecrets"
    effect    = "Allow"
    actions   = ["secretsmanager:ListSecrets"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "external_secrets" {
  name        = "${local.name_prefix}-external-secrets"
  description = "Read-only access to the secrets under oficina/${var.environment}/"
  policy      = data.aws_iam_policy_document.external_secrets.json

  tags = local.tags
}

module "irsa_external_secrets" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name = "${local.name_prefix}-external-secrets"

  role_policy_arns = {
    secrets = aws_iam_policy.external_secrets.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${local.eso_namespace}:${local.eso_service_account}"]
    }
  }

  tags = local.tags
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.chart_version_external_secrets
  namespace        = local.eso_namespace
  create_namespace = true

  values = [yamlencode({
    installCRDs = true
    serviceAccount = {
      create = true
      name   = local.eso_service_account
      annotations = {
        "eks.amazonaws.com/role-arn" = module.irsa_external_secrets.iam_role_arn
      }
    }
    webhook        = { create = true }
    certController = { create = true }
  })]

  # Ordered after the ALB controller: its webhook intercepts Service creation.
  depends_on = [module.eks, helm_release.aws_load_balancer_controller]
}

# Cluster-wide store: every ExternalSecret in oficina-<env> resolves against the
# Secrets Manager of this region using the ESO service account (IRSA).
resource "kubectl_manifest" "cluster_secret_store" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "oficina-secretsmanager"
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.region
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = local.eso_service_account
                namespace = local.eso_namespace
              }
            }
          }
        }
      }
    }
  })

  depends_on = [helm_release.external_secrets]
}
