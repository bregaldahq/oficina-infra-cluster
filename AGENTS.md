# oficina-infra-cluster — guia para agentes

Cluster do sistema Oficina Mecânica: EKS, node group, add-ons Helm, ECR, NLB interno com target
group e o `ClusterSecretStore`. Terraform com os providers `aws`, `kubernetes`, `helm` e
`kubectl`, que se autenticam via `aws eks get-token`. É aplicado depois da fundação, é
descartável e muda ocasionalmente.

O sistema tem quatro repos; o mapa, as regras entre eles e as ferramentas (`bin/ws`) ficam no
repositório principal `oficina-mecanica`. O contrato entre os repos é o
`docs/fase-3/CONTRATOS.md` do `oficina-api`. Se ele divergir daqui, **o documento vence**.

## O que cria

- `eks.tf`: cluster EKS (versão em `envs/*.tfvars`, hoje `1.31`) e um managed node group de
  `t3.medium`, de 2 a 4 nodes, nas **subnets públicas** com IP público. Cada node recebe o SG do
  node, o SG do cluster e o SG crachá do banco (`db/client_sg_id`). `capacity_type` é `SPOT` em
  hml e `ON_DEMAND` em prod.
- `ecr.tf`: repositório `oficina-api`, com scan on push e retenção das últimas 10 imagens.
- `nlb.tf`: NLB **interno**, target group `target_type = ip` e listener `:80`, todos criados
  **pelo Terraform**, não pelo Load Balancer Controller. A Lambda aplica antes da app e precisa
  dos ARNs já existentes. Os Pods entram no target group pelo `TargetGroupBinding` da aplicação.
- `addons-*.tf`:
  - `aws-load-balancer-controller` (IRSA), que só registra os targets;
  - `metrics-server`, pré-requisito do HPA;
  - `external-secrets` (IRSA restrita aos 2 segredos), que cria o `ClusterSecretStore`
    **`oficina-secretsmanager`**;
  - `nri-bundle` (New Relic).
- `namespaces.tf`: `oficina-hml` e `oficina-prod`.
- `rbac-app-deployer.tf`: dá ao role de CI da aplicação permissão sobre as CRDs
  `TargetGroupBinding` e `ExternalSecret`. CRD nova usada pela app precisa entrar aqui.
- `ssm.tf`: publica `eks/*`, `ecr/repository_url` e `nlb/*`.

## Contratos

- **Consome:** `network/*`, `db/client_sg_id` e os ARNs dos segredos (fundação).
- **Publica:** `eks/*`, `ecr/repository_url`, `nlb/arn`, `nlb/listener_arn`,
  `nlb/target_group_arn` e `eks/namespace` (seção 2).
- O nome `oficina-secretsmanager` do `ClusterSecretStore` é contrato com o `ExternalSecret` da
  aplicação (adendo 2).

## Validar

- A partir do repositório principal: `bin/ws verify --repo cluster` (`fmt`, `validate` sem
  backend e `tflint`, que não bloqueia, como no CI).
- Direto: `terraform fmt -check -recursive`, `terraform init -backend=false`,
  `terraform validate`.

O `.terraform.lock.hcl` é versionado: se mudar provider, atualize-o com
`bin/ws exec cluster sh -c 'terraform init -backend=false && terraform providers lock
-platform=linux_amd64 -platform=darwin_arm64 -platform=darwin_amd64'` (o `init` vem antes por
causa dos módulos) e commite.

## Armadilhas

| Sintoma | Causa | O que pega |
|---|---|---|
| O deploy da app volta `forbidden` | A app passou a usar uma CRD sem permissão no `rbac-app-deployer.tf` | `bin/check-contracts.py` (RBAC-1) |
| A exclusão do target group trava no destroy | Sobrou um `TargetGroupBinding` órfão | Ordem: remova os workloads da app antes de destruir o cluster |
| O `Secret` `oficina-secret` não aparece na app | O nome do `ClusterSecretStore` mudou de um lado só | `bin/check-contracts.py` (ESO-1) |
| O HPA fica `<unknown>` | O `metrics-server` caiu | Smoke test do `deploy.yml` |
| O apply troca todos os nodes | A tag `Repo` ou outra tag do node group mudou | `bin/check-contracts.py` (NOME-1); a tag continua `oficina-infra-k8s` |

O `destroy.yml` só roda por disparo manual e pede o nome do ambiente. **Agente não dispara.**

## Convenções

- Branches `feat/…`, `fix/…`, `chore/…`, `ci/…`, com PR para `develop`. O PR roda `plan` em hml
  e prod e comenta no PR.
- Commits em português, sem acento no assunto, Conventional Commits com escopo
  (`fix(eks): ...`), só com o nome do autor.
- Agente nunca roda `terraform apply`/`destroy`, `kubectl`/`helm` que alteram o cluster, nem
  dispara workflow.
