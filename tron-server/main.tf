# ---------------------------------------------------------------------------------------------------------------------
# LAUNCH A TRON SERVER
# This code deploys a Tron server with an ALB, Route 53 DNS, and an EBS volume
# ---------------------------------------------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# CONFIGURE OUR AWS CONNECTION
# ------------------------------------------------------------------------------

provider "aws" {
  region = "${var.aws_region}"

  # Only these AWS Account IDs may be operated on by this template
  allowed_account_ids = [
    "${var.aws_account_id}",
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE REMOTE STATE STORAGE
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  # The configuration for this backend will be filled in by Terragrunt
  backend "s3" {}

  # Only allow this Terraform version. Note that if you upgrade to a newer version, Terraform won't allow you to use an
  # older version, so when you upgrade, you should upgrade everyone on your team and your CI servers all at once.
  required_version = "= 0.11.7"
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE TRON SERVER, ALB, AND EBS VOLUME
# ---------------------------------------------------------------------------------------------------------------------

module "tron" {

  source = "../_modules/tron-server"

  name                       = "${var.name}"
  aws_region                 = "${var.aws_region}"
  aws_account_id             = "${var.aws_account_id}"
  environment_name           = "${var.vpc_name}"
  ami_id                     = "${var.ami_id}"
  key_pair_name              = "${var.key_pair_name}"
  instance_type              = "${var.instance_type}"
  enable_detailed_monitoring = "${var.enable_detailed_monitoring}"
  user_data                  = "${data.template_file.user_data.rendered}"
  skip_rolling_deploy        = true

  # ELB Health Checks

  health_check_interval                = "${var.health_check_interval}"
  health_check_path                    = "${var.health_check_path}"
  tron_node_http_health_check_path     = "${var.tron_node_http_health_check_path}"
  tron_solidity_http_health_check_path = "${var.tron_solidity_http_health_check_path}"
  health_check_timeout                 = "${var.health_check_timeout}"
  health_check_healthy_threshold       = "${var.health_check_healthy_threshold}"
  health_check_unhealthy_threshold     = "${var.health_check_unhealthy_threshold}"
  skip_health_check                    = "${var.skip_health_check}"
  health_check_type                    = "${var.health_check_type}"

  # EBS Volumes

  ebs_optimized                 = "${var.ebs_optimized}"
  root_block_device_volume_type = "${var.root_block_device_volume_type}"
  root_block_device_volume_size = "${var.root_block_device_volume_size}"
  ebs_volume_type               = "${var.ebs_volume_type}"
  ebs_volume_size               = "${var.ebs_volume_size}"
  ebs_volume_encrypted          = "${var.ebs_volume_encrypted}"

  # VPC and Subnets to deploy into. Tron in 1x Private SN, ALB in all Public SNs.

  vpc_id         = "${data.terraform_remote_state.deploy_vpc.vpc_id}"
  tron_subnet_id = "${element(data.terraform_remote_state.deploy_vpc.private_app_subnet_ids, 0)}"
  alb_subnet_ids = [
    "${data.terraform_remote_state.deploy_vpc.public_subnet_ids}",
  ]

  # var.hosted_zone_domain_name (aws.example.com) and a wildcard ACM certificate for that domain name (*.aws.example.com).
  # This will create a public domain name for the Tron server of the form tron.aws.example.com

  create_route53_entry = "${var.create_route53_entry}"
  hosted_zone_id       = "${data.terraform_remote_state.route53.primary_domain_hosted_zone_id}"
  domain_name          = "${var.dns_name}.${data.terraform_remote_state.route53.primary_domain_name}"
  acm_cert_domain_name = "*.${substr(data.terraform_remote_state.route53.primary_domain_name, 0, length(data.terraform_remote_state.route53.primary_domain_name) -1)}"

  # Setup internal DNS and use ENI(s) and attach at boot.

  route53_hosted_zone_id = "${data.terraform_remote_state.mgmt_route53_internal.internal_services_hosted_zone_id}"
  dns_name               = "${var.dns_name}.${data.terraform_remote_state.mgmt_route53_internal.internal_services_domain_name}"

  # We allow inbound HTTP connections from the trusted VPN server.
  # Since this is a Public ALB, we need to let in from the default of everywhere 0.0.0.0/0

  allow_incoming_http_from_cidr_blocks = [
    "0.0.0.0/0",
  ]
  allow_incoming_http_from_security_group_ids = [
    "${data.terraform_remote_state.openvpn_server.security_group_id}",
  ]

  # We allow inbound SSH connections from the VPN Server.

  allow_ssh_from_cidr_blocks = []
  allow_ssh_from_security_group_ids = [
    "${data.terraform_remote_state.openvpn_server.security_group_id}",
  ]

  # The ALB is needs to be accessed by the internet for specific ports

  is_internal_alb = false

  # Tron Ports to expose

  tron_node_port             = "${var.tron_node_port}"
  tron_solidity_port         = "${var.tron_solidity_port}"
  tron_peer_listen_port      = "${var.tron_peer_listen_port}"
  tron_public_https_api_port = "${var.tron_public_https_api_port}"
  alb_target_group_protocol  = "${var.alb_target_group_protocol}"

  # Setup ALB Logs to S3 Bucket

  enable_alb_access_logs                = "${var.enable_alb_access_logs}"
  alb_access_logs_s3_bucket_name        = "${var.alb_access_logs_s3_bucket_name}"
  alb_access_logs_force_destroy         = "${var.alb_access_logs_force_destroy}"
  num_days_after_which_archive_log_data = "${var.num_days_after_which_archive_log_data}"
  num_days_after_which_delete_log_data  = "${var.num_days_after_which_delete_log_data}"
  custom_tags                           = "${var.custom_tags}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE THE USER DATA SCRIPT THIS SERVER WILL RUN DURING BOOT
# ---------------------------------------------------------------------------------------------------------------------

data "template_file" "user_data" {
  template = "${file("${path.module}/user-data/user-data.sh")}"
}

# ------------------------------------------------------------------------------
# GRAB VARIABLES FROM THE TERRAFORM.TFSTATE FILE(S)
# ------------------------------------------------------------------------------

data "terraform_remote_state" "mgmt_vpc" {
  backend = "s3"

  config {
    region = "${var.terraform_state_aws_region}"
    bucket = "${var.terraform_state_s3_bucket}"
    key    = "${var.aws_region}/mgmt/vpc/terraform.tfstate"
  }
}

data "terraform_remote_state" "deploy_vpc" {
  backend = "s3"

  config {
    region = "${var.terraform_state_aws_region}"
    bucket = "${var.terraform_state_s3_bucket}"
    key    = "${var.aws_region}/${var.vpc_name}/vpc/terraform.tfstate"
  }
}

data "terraform_remote_state" "route53" {
  backend = "s3"

  config {
    region = "${var.terraform_state_aws_region}"
    bucket = "${var.terraform_state_s3_bucket}"
    key    = "_global/route53-public/terraform.tfstate"
  }
}

data "terraform_remote_state" "mgmt_route53_internal" {
  backend = "s3"

  config {
    region = "${var.terraform_state_aws_region}"
    bucket = "${var.terraform_state_s3_bucket}"
    key    = "${var.aws_region}/${var.vpc_name}/networking/route53-private/terraform.tfstate"
  }
}

data "terraform_remote_state" "openvpn_server" {
  backend = "s3"

  config {
    region = "${var.terraform_state_aws_region}"
    bucket = "${var.terraform_state_s3_bucket}"
    key    = "${var.aws_region}/mgmt/openvpn-server/terraform.tfstate"
  }
}

data "terraform_remote_state" "sns_alarms" {
  backend = "s3"

  config {
    region = "${var.terraform_state_aws_region}"
    bucket = "${var.terraform_state_s3_bucket}"
    key    = "${var.aws_region}/_global/${var.remote_state_sns_topic}/terraform.tfstate"
  }
}
