resource "aws_lb" "api_internal" {
  name                             = "ipi-disconnected-int"
  load_balancer_type               = "network"
  subnets                          = data.aws_subnet.private.*.id
  internal                         = true
  enable_cross_zone_load_balancing = true

  tags = merge(
    {
      "Name" = "ipi-disconnected-int"
    },
    var.tags,
  )

  timeouts {
    create = "20m"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_lb" "api_external" {
  count = local.public_endpoints ? 1 : 0

  name                             = "ipi-disconnected-ext"
  load_balancer_type               = "network"
  subnets                          = data.aws_subnet.public.*.id
  internal                         = false
  enable_cross_zone_load_balancing = true

  tags = merge(
    {
      "Name" = "ipi-disconnected-ext"
    },
    var.tags,
  )

  timeouts {
    create = "20m"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_lb_target_group" "api_internal" {
  name     = "ipi-disconnected-aint"
  protocol = "TCP"
  port     = 6443
  vpc_id   = data.aws_vpc.cluster_vpc.id

  target_type = "ip"

  tags = merge(
    {
      "Name" = "ipi-disconnected-aint"
    },
    var.tags,
  )

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
    port                = 6443
    protocol            = "HTTPS"
    path                = "/readyz"
  }
}

resource "aws_lb_target_group" "api_external" {
  count = local.public_endpoints ? 1 : 0

  name     = "ipi-disconnected-aext"
  protocol = "TCP"
  port     = 6443
  vpc_id   = data.aws_vpc.cluster_vpc.id

  target_type = "ip"

  tags = merge(
    {
      "Name" = "ipi-disconnected-aext"
    },
    var.tags,
  )

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
    port                = 6443
    protocol            = "HTTPS"
    path                = "/readyz"
  }
}

resource "aws_lb_target_group" "services" {
  name     = "ipi-disconnected-sint"
  protocol = "TCP"
  port     = 22623
  vpc_id   = data.aws_vpc.cluster_vpc.id

  target_type = "ip"

  tags = merge(
    {
      "Name" = "ipi-disconnected-sint"
    },
    var.tags,
  )

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
    port                = 22623
    protocol            = "HTTPS"
    path                = "/healthz"
  }
}

resource "aws_lb_listener" "api_internal_api" {
  load_balancer_arn = aws_lb.api_internal.arn
  protocol          = "TCP"
  port              = "6443"

  default_action {
    target_group_arn = aws_lb_target_group.api_internal.arn
    type             = "forward"
  }
}

resource "aws_lb_listener" "api_internal_services" {
  load_balancer_arn = aws_lb.api_internal.arn
  protocol          = "TCP"
  port              = "22623"

  default_action {
    target_group_arn = aws_lb_target_group.services.arn
    type             = "forward"
  }
}

resource "aws_lb_listener" "api_external_api" {
  count = local.public_endpoints ? 1 : 0

  load_balancer_arn = aws_lb.api_external[0].arn
  protocol          = "TCP"
  port              = "6443"

  default_action {
    target_group_arn = aws_lb_target_group.api_external[0].arn
    type             = "forward"
  }
}



output "vpc_id" {
  value = data.aws_vpc.cluster_vpc.id
}

output "vpc_cidrs" {
  value = var.cidr_blocks
}

output "az_to_private_subnet_id" {
  value = zipmap(data.aws_subnet.private.*.availability_zone, data.aws_subnet.private.*.id)
}

output "az_to_public_subnet_id" {
  value = zipmap(data.aws_subnet.public.*.availability_zone, data.aws_subnet.public.*.id)
}

output "public_subnet_ids" {
  value = data.aws_subnet.public.*.id
}

output "private_subnet_ids" {
  value = data.aws_subnet.private.*.id
}

output "master_sg_id" {
  value = aws_security_group.master.id
}

output "worker_sg_id" {
  value = aws_security_group.worker.id
}

output "aws_lb_target_group_arns" {
  // The order of the list is very important because the consumers assume the 3rd item is the external aws_lb_target_group
  // Because of the issue https://github.com/hashicorp/terraform/issues/12570, the consumers cannot use a dynamic list for count
  // and therefore are force to implicitly assume that the list is of aws_lb_target_group_arns_length - 1, in case there is no api_external
  value = compact(
    concat(
      aws_lb_target_group.api_internal.*.arn,
      aws_lb_target_group.services.*.arn,
      aws_lb_target_group.api_external.*.arn,
    ),
  )
}

output "aws_lb_target_group_arns_length" {
  // 2 for private endpoints and 1 for public endpoints
  value = "3"
}

output "aws_lb_api_external_dns_name" {
  value = local.public_endpoints ? aws_lb.api_external[0].dns_name : null
}

output "aws_lb_api_external_zone_id" {
  value = local.public_endpoints ? aws_lb.api_external[0].zone_id : null
}

output "aws_lb_api_internal_dns_name" {
  value = aws_lb.api_internal.dns_name
}

output "aws_lb_api_internal_zone_id" {
  value = aws_lb.api_internal.zone_id
}
