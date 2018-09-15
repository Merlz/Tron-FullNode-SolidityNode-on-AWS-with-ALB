# ---------------------------------------------------------------------------------------------------------------------
# ENVIRONMENT VARIABLES
# Define these secrets as environment variables
# ---------------------------------------------------------------------------------------------------------------------

# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY

# ---------------------------------------------------------------------------------------------------------------------
# LOCAL TESTING PARAMETERS
# These are the variables we have to pass in to the command line to test the configuration and must be done from this directory
# pwd /code/example/infra-live/main-acct/us-east-1/stage/services/tron-server
# ---------------------------------------------------------------------------------------------------------------------

# terragrunt plan --terragrunt-source-update --terragrunt-source ../../../../../../infra-live-modules/terraform/aws//services/tron-server
# terragrunt apply --terragrunt-source-update --terragrunt-source ../../../../../../infra-live-modules/terraform/aws//services/tron-server
# terragrunt destroy --terragrunt-source-update --terragrunt-source ../../../../../../infra-live-modules/terraform/aws//services/tron-server

# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# This is the configuration for Terragrunt, a thin wrapper for Terraform that supports locking and enforces best
# practices: https://github.com/gruntwork-io/terragrunt
# ---------------------------------------------------------------------------------------------------------------------

terragrunt = {
  # Terragrunt will copy the Terraform configurations specified by the source parameter, along with any files in the
  # working directory, into a temporary folder, and execute your Terraform commands in that folder.
  terraform {
    source = "git::ssh://git@github.com/EXAMPLE/infra-live-modules.git//terraform/aws/services/tron-server?ref=master"
  }

  # Include all settings from the root terraform.tfvars file
  include {
    path = "${find_in_parent_folders()}"
  }

  # When using the terragrunt xxx-all commands (e.g., apply-all, plan-all), deploy these dependencies before this module
  dependencies = {
    paths = [
      "../../vpc",
      "../../kms-master-key",
      "../../networking/route53-private",
      "../../../../_global/route53-public",
      "../../../_global/route53-sns-topics",
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above
# ---------------------------------------------------------------------------------------------------------------------

name = "tron-server"

# Only used for emergencies, all users will connect through grunt-ssh using their IAM account & SSH key
key_pair_name = "tron-us-east-1-v1"

dns_name = "tron-0"

create_route53_entry = true

# The AMI of the packer ripple-server-ubuntu-16 image that was pre-built
ami_id = ""

instance_type = "m5.2xlarge"

skip_rolling_deploy = false

# EBS Volume data
ebs_device_name = "/dev/sdf"

ebs_mount_point = "/data"

# Only false for testing on small instance types
# When using m5.4xlarge, set to true
ebs_optimized = true

root_block_device_volume_type = "gp2"

root_block_device_volume_size = 40

ebs_volume_type = "gp2"

ebs_volume_size = 1000

ebs_volume_encrypted = false

# ALB Health Checks
skip_health_check = false

health_check_grace_period = 300

health_check_interval = 180

health_check_timeout = 60

health_check_healthy_threshold = 2

health_check_unhealthy_threshold = 3

health_check_type = "EC2"

tron_node_http_health_check_path = "/wallet/listnodes"

tron_solidity_http_health_check_path = "/walletsolidity/getnowblock"

tron_peer_listen_port = 18888

tron_public_https_api_port = 443

tron_node_port = 8090

tron_solidity_port = 8091

alb_target_group_protocol = "HTTP"

enable_detailed_monitoring = true

# Used for alerts sent to devops-alerts-test in Slack
remote_state_sns_topic = "sns-services-alarms-for-tests"

# For Stage or Prod alerts sent to devops-alerts in Slack
#remote_state_sns_topic = "sns-services-alarms"

custom_tags = {
  ManagedBy   = "terraform"
  Environment = "stage"
}
