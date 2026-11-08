# ---------------------------------------------------------------------------
# Internal NLB consumed by the API Gateway VPC Link (oficina-gateway-auth).
#
# Ownership decision (see README, "NLB: quem cria o quê"):
#   * Terraform owns the load balancer, the target group and the :80 listener,
#     so that /oficina/<env>/nlb/arn and /oficina/<env>/nlb/listener_arn are
#     stable ARNs available *before* the application is deployed. The VPC Link
#     integration of the API Gateway needs them at apply time.
#   * The AWS Load Balancer Controller registers the *targets* (pod IPs) into
#     this target group, driven by the application Service. See README.
# ---------------------------------------------------------------------------
resource "aws_lb" "internal" {
  name               = "${local.name_prefix}-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = local.private_subnet_ids

  enable_cross_zone_load_balancing = true

  tags = merge(local.tags, { Name = "${local.name_prefix}-nlb" })
}

resource "aws_lb_target_group" "api" {
  name        = "${local.name_prefix}-api-tg"
  port        = 80
  protocol    = "TCP"
  vpc_id      = local.vpc_id
  target_type = "ip" # pod IPs, registered by the AWS Load Balancer Controller

  health_check {
    protocol            = "HTTP"
    path                = "/api/health"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }

  # The controller adds and removes targets as pods come and go.
  lifecycle {
    ignore_changes = [tags_all]
  }

  tags = merge(local.tags, { Name = "${local.name_prefix}-api-tg" })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# Allows the NLB (which lives in the private subnets) to health check and reach
# the application pods running on the worker nodes.
resource "aws_security_group_rule" "nodes_from_vpc_http" {
  type              = "ingress"
  description       = "Internal NLB to oficina-api pods"
  security_group_id = module.eks.node_security_group_id
  from_port         = 1025
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = [local.vpc_cidr]
}
