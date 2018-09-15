# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY TRON
# This module can be used to run a Tron server. It creates the following resources:
#
# - An ASG to run Tron and automatically redeploy it if it crashes
# - An EBS volume for Tron that persists between redeploys
# - An ALB to route traffic to Tron
# - A Route 53 DNS A record for Tron pointing at the ALB
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ---------------------------------------------------------------------------------------------------------------------
# LAUNCH TRON
# We use the server-group module so that (a) we have an ASG that can restart Tron nodes that fail, but (b) the ASG
# works properly with a persistent EBS volume.
# ---------------------------------------------------------------------------------------------------------------------

module "tron" {

  # REMOMVED THIS MODULE DUE TO IT BEING A GRUNTWORK SUBSCRIPTION SERVICE
  source = "../../_modules/server-group"

  name          = "${var.name}"
  size          = 1
  instance_type = "${var.instance_type}"
  ami_id        = "${var.ami_id}"
  user_data     = "${var.user_data}"
  aws_region    = "${var.aws_region}"
  vpc_id        = "${var.vpc_id}"
  subnet_ids = [
    "${var.tron_subnet_id}",
  ]
  tenancy                    = "${var.tenancy}"
  health_check_type          = "${var.health_check_type}"
  health_check_grace_period  = "${var.health_check_grace_period}"
  enable_detailed_monitoring = "${var.enable_detailed_monitoring}"
  alb_target_group_arns = [
    "${aws_alb_target_group.tron_peer.arn}",
    "${aws_alb_target_group.tron_node.arn}",
    "${aws_alb_target_group.tron_solidity.arn}",
  ]
  script_log_level            = "${var.script_log_level}"
  skip_health_check           = "${var.skip_health_check}"
  skip_rolling_deploy         = "${var.skip_rolling_deploy}"
  deployment_batch_size       = "${var.deployment_batch_size}"
  wait_for_capacity_timeout   = "${var.wait_for_capacity_timeout}"
  associate_public_ip_address = false
  key_pair_name               = "${var.key_pair_name}"
  allow_ssh_from_cidr_blocks = [
    "${var.allow_ssh_from_cidr_blocks}",
  ]
  allow_ssh_from_security_group_ids = [
    "${var.allow_ssh_from_security_group_ids}",
  ]
  ebs_optimized                 = "${var.ebs_optimized}"
  root_block_device_volume_type = "${var.root_block_device_volume_type}"
  root_block_device_volume_size = "${var.root_block_device_volume_size}"
  ebs_volumes = [
    {
      type      = "${var.ebs_volume_type}"
      size      = "${var.ebs_volume_size}"
      encrypted = "${var.ebs_volume_encrypted}"
    },
  ]
  # Internal Route53 Setup. Set var.num_enis to match the var.size. We only need 1 Tron server, so size & enis are both 1
  num_enis = 1
  dns_names = [
    "${var.dns_name}",
  ]
  route53_hosted_zone_id = "${var.route53_hosted_zone_id}"
  custom_tags            = "${var.custom_tags}"
}

# ---------------------------------------------------------------------------------------------------------------------
# UPDATE THE SECURITY GROUP TO ALLOW CONNECTIONS TO TRON FROM THE ALB
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group_rule" "allow_incoming_node_from_alb" {
  type                     = "ingress"
  from_port                = "${var.tron_node_port}"
  to_port                  = "${var.tron_node_port}"
  protocol                 = "tcp"
  source_security_group_id = "${module.alb.alb_security_group_id}"
  security_group_id        = "${module.tron.security_group_id}"
}

resource "aws_security_group_rule" "allow_incoming_solidity_from_alb" {
  type                     = "ingress"
  from_port                = "${var.tron_solidity_port}"
  to_port                  = "${var.tron_solidity_port}"
  protocol                 = "tcp"
  source_security_group_id = "${module.alb.alb_security_group_id}"
  security_group_id        = "${module.tron.security_group_id}"
}

resource "aws_security_group_rule" "allow_incoming_udp_node_peer_from_alb" {
  type                     = "ingress"
  from_port                = "${var.tron_peer_listen_port}"
  to_port                  = "${var.tron_peer_listen_port}"
  protocol                 = "udp"
  source_security_group_id = "${module.alb.alb_security_group_id}"
  security_group_id        = "${module.tron.security_group_id}"
}

resource "aws_security_group_rule" "allow_incoming_udp_node_peer_to_alb" {
  type              = "ingress"
  from_port         = "${var.tron_peer_listen_port}"
  to_port           = "${var.tron_peer_listen_port}"
  protocol          = "udp"
  security_group_id = "${module.alb.alb_security_group_id}"

  cidr_blocks = [
    "0.0.0.0/0",
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ALB TO ROUTE TRAFFIC TO TRON
# The ALB handles SSL termination and allows us to safely access Tron at ports 18888, 8090 & 8091
# ---------------------------------------------------------------------------------------------------------------------

module "alb" {
  # REMOMVED THIS MODULE DUE TO IT BEING A GRUNTWORK SUBSCRIPTION SERVICE
  source = "../../_modules/alb"

  aws_account_id = "${var.aws_account_id}"
  aws_region     = "${var.aws_region}"

  alb_name         = "${var.name}"
  environment_name = "${var.environment_name}"
  is_internal_alb  = "${var.is_internal_alb}"

  # Setup ALB access logs in S3 bucket
  enable_alb_access_logs         = "${var.enable_alb_access_logs}"
  alb_access_logs_s3_bucket_name = "${var.alb_access_logs_s3_bucket_name}"

  http_listener_ports = []

  https_listener_ports_and_acm_ssl_certs = [
    {
      port            = "${var.tron_public_https_api_port}"
      tls_domain_name = "${var.acm_cert_domain_name}"
    },
    {
      port            = "${var.tron_peer_listen_port}"
      tls_domain_name = "${var.acm_cert_domain_name}"
    },
  ]

  vpc_id = "${var.vpc_id}"

  vpc_subnet_ids = [
    "${var.alb_subnet_ids}",
  ]

  allow_inbound_from_cidr_blocks = [
    "${var.allow_incoming_http_from_cidr_blocks}",
  ]

  allow_inbound_from_security_group_ids = [
    "${var.allow_incoming_http_from_security_group_ids}",
  ]

  custom_tags = "${var.custom_tags}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE ALB TARGET GROUPS FOR TRON
# This will perform health checks on Tron and receive traffic from the ALB for certain paths/domains.
# ---------------------------------------------------------------------------------------------------------------------

# NODE Port
resource "aws_alb_target_group" "tron_node" {
  name     = "${var.name}-node"
  port     = "${var.tron_node_port}"
  protocol = "${var.alb_target_group_protocol}"
  vpc_id   = "${var.vpc_id}"

  # Give existing connections 10 seconds to complete before deregistering an instance. The default delay is 300 seconds
  # (5 minutes), which significantly slows down redeploys. In theory, the ALB should deregister the instance as long as
  # there are no open connections; in practice, it waits the full five minutes every time.
  deregistration_delay = 10

  # Stickiness is only valid if used with Load Balancers of type Application
  stickiness {
    type            = "${var.alb_target_group_stickiness_type}"
    cookie_duration = "${var.alb_target_group_stickiness_cookie_duration}"
    enabled         = "${var.alb_target_group_stickiness_enabled}"
  }

  health_check {
    interval            = "${var.health_check_interval}"
    path                = "${var.tron_node_http_health_check_path}"
    protocol            = "${var.health_check_protocol}"
    timeout             = "${var.health_check_timeout}"
    healthy_threshold   = "${var.health_check_healthy_threshold}"
    unhealthy_threshold = "${var.health_check_unhealthy_threshold}"
    matcher             = "${var.health_check_matcher}"
  }
}

# SOLIDITY Port
resource "aws_alb_target_group" "tron_solidity" {
  name     = "${var.name}-solidity"
  port     = "${var.tron_solidity_port}"
  protocol = "${var.alb_target_group_protocol}"
  vpc_id   = "${var.vpc_id}"

  # Give existing connections 10 seconds to complete before deregistering an instance. The default delay is 300 seconds
  # (5 minutes), which significantly slows down redeploys. In theory, the ALB should deregister the instance as long as
  # there are no open connections; in practice, it waits the full five minutes every time.
  deregistration_delay = 10

  # Stickiness is only valid if used with Load Balancers of type Application
  stickiness {
    type            = "${var.alb_target_group_stickiness_type}"
    cookie_duration = "${var.alb_target_group_stickiness_cookie_duration}"
    enabled         = "${var.alb_target_group_stickiness_enabled}"
  }

  health_check {
    interval            = "${var.health_check_interval}"
    path                = "${var.tron_solidity_http_health_check_path}"
    protocol            = "${var.health_check_protocol}"
    timeout             = "${var.health_check_timeout}"
    healthy_threshold   = "${var.health_check_healthy_threshold}"
    unhealthy_threshold = "${var.health_check_unhealthy_threshold}"
    matcher             = "${var.health_check_matcher}"
  }
}

# PEER Port
resource "aws_alb_target_group" "tron_peer" {
  name     = "${var.name}-peer"
  port     = "${var.tron_peer_listen_port}"
  protocol = "${var.alb_target_group_protocol}"
  vpc_id   = "${var.vpc_id}"

  # Give existing connections 10 seconds to complete before deregistering an instance. The default delay is 300 seconds
  # (5 minutes), which significantly slows down redeploys. In theory, the ALB should deregister the instance as long as
  # there are no open connections; in practice, it waits the full five minutes every time.
  deregistration_delay = 10

  # Stickiness is only valid if used with Load Balancers of type Application
  stickiness {
    type            = "${var.alb_target_group_stickiness_type}"
    cookie_duration = "${var.alb_target_group_stickiness_cookie_duration}"
    enabled         = "${var.alb_target_group_stickiness_enabled}"
  }

  health_check {
    interval            = "${var.health_check_interval}"
    path                = "${var.health_check_path}"
    protocol            = "${var.health_check_protocol}"
    timeout             = "${var.health_check_timeout}"
    healthy_threshold   = "${var.health_check_healthy_threshold}"
    unhealthy_threshold = "${var.health_check_unhealthy_threshold}"
    matcher             = "${var.health_check_matcher}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD LISTENER RULES TO SEND ALL HTTPS REQUESTS TO THE TRON TARGET GROUPS
# ---------------------------------------------------------------------------------------------------------------------

# API /wallet/* NODE Listener Rule
resource "aws_alb_listener_rule" "node_wallet_https_api" {
  listener_arn = "${lookup(module.alb.listener_arns, var.tron_public_https_api_port)}"
  priority     = 115

  condition {
    field = "path-pattern"

    values = [
      "/wallet/*",
    ]
  }

  action {
    target_group_arn = "${aws_alb_target_group.tron_node.arn}"
    type             = "forward"
  }
}

# API /walletsolidity/* SOLIDITY Listener Rule
resource "aws_alb_listener_rule" "solidity_walletsolidity_https_api" {
  listener_arn = "${lookup(module.alb.listener_arns, var.tron_public_https_api_port)}"
  priority     = 100

  condition {
    field = "path-pattern"

    values = [
      "/walletsolidity/*",
    ]
  }

  action {
    target_group_arn = "${aws_alb_target_group.tron_solidity.arn}"
    type             = "forward"
  }
}

# API /walletextension/* SOLIDITY Listener Rule
resource "aws_alb_listener_rule" "solidity_walletextension_solidity_https_api" {
  listener_arn = "${lookup(module.alb.listener_arns, var.tron_public_https_api_port)}"
  priority     = 105

  condition {
    field = "path-pattern"

    values = [
      "/walletextension/*",
    ]
  }

  action {
    target_group_arn = "${aws_alb_target_group.tron_solidity.arn}"
    type             = "forward"
  }
}

# PEER Listener Rule
resource "aws_alb_listener_rule" "https_peer" {
  listener_arn = "${lookup(module.alb.listener_arns, var.tron_peer_listen_port)}"
  priority     = 110

  condition {
    field = "path-pattern"

    values = [
      "*",
    ]
  }

  action {
    target_group_arn = "${aws_alb_target_group.tron_peer.arn}"
    type             = "forward"
  }
}

# ----------------------------------------------------------------------------------------------------------------------
# CREATE A DNS RECORD FOR THE ALB USING ROUTE 53
# ----------------------------------------------------------------------------------------------------------------------

resource "aws_route53_record" "tron" {
  count = "${var.create_route53_entry}"

  zone_id = "${var.hosted_zone_id}"
  name    = "${var.domain_name}"
  type    = "A"

  alias {
    name                   = "${module.alb.alb_dns_name}"
    zone_id                = "${module.alb.alb_hosted_zone_id}"
    evaluate_target_health = true
  }
}
