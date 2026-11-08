variable "environment" {
  description = "Deployment environment. Must match the SSM parameter namespace published by oficina-infra-fundacao."
  type        = string

  validation {
    condition     = contains(["hml", "prod"], var.environment)
    error_message = "environment must be one of: hml, prod."
  }
}

variable "region" {
  description = "AWS region. Fase 3 is pinned to us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "cluster_version" {
  description = "EKS control plane version."
  type        = string
  default     = "1.30"
}

variable "node_instance_types" {
  description = "Instance types of the managed node group."
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes (headroom for the oficina-api HPA)."
  type        = number
  default     = 4
}

variable "capacity_type" {
  description = "SPOT keeps the development cost low; ON_DEMAND is used for the graded delivery."
  type        = string
  default     = "SPOT"

  validation {
    condition     = contains(["SPOT", "ON_DEMAND"], var.capacity_type)
    error_message = "capacity_type must be SPOT or ON_DEMAND."
  }
}

variable "node_disk_size" {
  description = "Root EBS volume size (GiB) of each worker node."
  type        = number
  default     = 20
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint. Narrow this down for prod."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ecr_repository_name" {
  description = "ECR repository that holds the oficina-api image."
  type        = string
  default     = "oficina-api"
}

variable "ecr_image_retention_count" {
  description = "How many images the ECR lifecycle policy keeps."
  type        = number
  default     = 10
}

variable "newrelic_license_key" {
  description = "New Relic ingest license key. Injected by CI from the NEW_RELIC_LICENSE_KEY secret; never committed."
  type        = string
  sensitive   = true
  default     = ""
}

variable "newrelic_enabled" {
  description = "Installs the nri-bundle chart. Automatically skipped when no license key is provided."
  type        = bool
  default     = true
}

# Chart versions are pinned so that a re-apply is reproducible.
variable "chart_version_aws_load_balancer_controller" {
  type    = string
  default = "1.8.1"
}

variable "chart_version_metrics_server" {
  type    = string
  default = "3.12.1"
}

variable "chart_version_external_secrets" {
  type    = string
  default = "0.9.20"
}

variable "chart_version_nri_bundle" {
  type    = string
  default = "5.0.83"
}

variable "app_ci_role_arn" {
  description = <<-DESC
    IAM role used by the application repository's pipeline, granted access to the
    application namespaces inside the cluster.

    Without this the app pipeline authenticates to AWS fine and is then rejected by the
    Kubernetes API — EKS authorisation is separate from IAM.
  DESC
  type        = string
  default     = ""
}
