# ---------------------------------------------------------------------------------------------------------------------
# ENVIRONMENT VARIABLES
# Define these secrets as environment variables
# ---------------------------------------------------------------------------------------------------------------------

# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY

# ----------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables must be passed in by the templates using this module.
# ----------------------------------------------------------------------------------------------------------------------

variable "ami_id" {
  description = "The ID of the Amazon Machine Image (AMI) to run for Tron (e.g., ami-abcd1234). Should be built from the Packer template in packer/tron-server.json."
}

variable "aws_account_id" {
  description = "The ID of the AWS Account in which to create resources."
}

variable "key_pair_name" {
  description = "The name of an EC2 Key Pair to associate with each server for SSH access. Set to an empty string to not associate a Key Pair."
}

variable "dns_name" {
  description = "The DNS name to add for this server in var.domain_name. For example, the hosted zone is aws.example.com and you set dns_name to tron, this server will have the domain tron.aws.example.com"
}

variable "terraform_state_aws_region" {
  description = "The AWS region of the S3 bucket used to store Terraform remote state"
}

variable "terraform_state_s3_bucket" {
  description = "The name of the S3 bucket used to store Terraform remote state"
}

variable "tron_peer_listen_port" {
  description = "The port Tron should listen on for Peer requests from other Nodes."
}

variable "tron_public_https_api_port" {
  description = "The port Tron should listen on for https API requests."
}

variable "tron_node_port" {
  description = "The port Tron should listen on for Node requests."
}

variable "tron_solidity_port" {
  description = "The port Tron should listen on for Solidity requests."
}

variable "alb_target_group_protocol" {
  description = "The protocol to use for routing traffic to the targets. Should be one of \"TCP\", \"HTTP\", \"HTTPS\" or \"TLS\"."
}

variable "remote_state_sns_topic" {
  description = "The name of the SNS topic to use from the remote state S3 bucket https://s3.console.aws.amazon.com/s3/buckets/xxxxx-terraform-state-store-17373/us-east-1/_global/?region=us-east-1&tab=overview.  Example: sns-services-alarms-for-tests or sns-services-alarms"
}

# ----------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These variables may be optionally passed in by the templates using this module to overwite the defaults.
# ----------------------------------------------------------------------------------------------------------------------

variable "enable_alb_access_logs" {
  description = "Set to true to enable the ALB to log all requests. Ideally, this variable wouldn't be necessary, but because Terraform can't interpolate dynamic variables in counts, we must explicitly include this. Enter true or false."
  default     = false
}

variable "alb_access_logs_s3_bucket_name" {
  description = "The S3 Bucket name where ALB logs should be stored. If left empty, no ALB logs will be captured."
  default     = ""
}

variable "alb_access_logs_force_destroy" {
  description = "A boolean that indicates whether this bucket should be destroyed, even if there are files in it, when you run Terraform destroy. Unless you are using this bucket only for test purposes, you'll want to leave this variable set to false."
  default     = false
}

variable "name" {
  description = "The name for the Tron ASG and to namespace all the resources created by this module."
  default     = "tron-server"
}

variable "aws_region" {
  description = "The AWS region to deploy to (e.g. us-east-1)."
  default     = "us-east-1"
}

variable "vpc_name" {
  description = "The name of the environment we're in (e.g., stage, prod, mgmt)."
  default     = "mgmt"
}

variable "instance_type" {
  description = "The type of EC2 Instance to run (e.g. t2.micro)."
  default     = "t2.micro"
}

variable "skip_rolling_deploy" {
  description = "If set to true, skip the rolling deployment, and destroy all the servers immediately. You should typically NOT enable this in prod, as it will cause downtime! The main use case for this flag is to make testing and cleanup easier. It can also be handy in case the rolling deployment code has a bug."
  default     = false
}

variable "health_check_type" {
  description = "The type of health check to use. Must be one of: EC2 or ELB. If you associate any load balancers with this server group via var.elb_names or var.alb_target_group_arns, you should typically set this parameter to ELB."
  default     = "EC2"
}

variable "skip_health_check" {
  description = "If set to true, skip the health check, and start a rolling deployment of Tron without waiting for it to initially be in a healthy state. This is primarily useful if the server group is in a broken state and you want to force a deployment anyway."
  default     = false
}

variable "health_check_grace_period" {
  description = "How long, in seconds, to wait after Tron deploys before checking its health."
  default     = 120
}

variable "health_check_interval" {
  description = "The approximate amount of time, in seconds, between health checks of an individual target. Minimum value 5 seconds, Maximum value 300 seconds."
  default     = 30
}

variable "health_check_path" {
  description = "The path on the server the ALB should use for health checks."
  default     = "/"
}

variable "tron_node_http_health_check_path" {
  description = "The path for the node health check"
  default     = "/"
}

variable "tron_solidity_http_health_check_path" {
  description = "The path for the solidity health check"
  default     = "/"
}

variable "health_check_timeout" {
  description = "The amount of time, in seconds, during which no response means a failed health check. For Application Load Balancers, the range is 2 to 60 seconds and the default is 5 seconds. For Network Load Balancers, you cannot set a custom value, and the default is 10 seconds for TCP and HTTPS health checks and 6 seconds for HTTP health checks."
  default     = 30
}

variable "health_check_healthy_threshold" {
  description = "The number of consecutive health checks successes required before considering an unhealthy target healthy"
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "The number of consecutive health check failures required before considering the target unhealthy . For Network Load Balancers, this value must be the same as the healthy_threshold."
  default     = 2
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring for the servers. This gives you more granularity with your CloudWatch metrics, but also costs more money."
  default     = false
}

# EBS Volume Vars
variable "ebs_volume_name_tag" {
  description = "The name name tags for the EBS Volume"
  default     = "ebs-volume-0"
}

variable "ebs_device_name" {
  description = "The EBS Volume device name"
  default     = "/dev/xvdh"
}

variable "ebs_mount_point" {
  description = "The location to mount the EBS Volume"
  default     = "/xrpdb"
}

variable "ebs_owner" {
  description = "The user owner of the EBS volume"
  default     = "ubuntu"
}

variable "ebs_optimized" {
  description = "Set to true to make Tron EBS-optimized."
  default     = false
}

variable "root_block_device_volume_type" {
  description = "The type of the root volume for Tron. Must be one of: standard, gp2, or io1."
  default     = "standard"
}

variable "root_block_device_volume_size" {
  description = "The size, in GB, of the root volume for Tron."
  default     = 40
}

variable "ebs_volume_type" {
  description = "The type of EBS volume to use for the Tron data dir. Must be one of: standard, gp2, or io1."
  default     = "gp2"
}

variable "ebs_volume_size" {
  description = "The size, in GB, of the EBS volume to use for the Tron data dir."
  default     = 100
}

variable "ebs_volume_encrypted" {
  description = "Set to true to use an encrypted EBS volume for the Tron data dir."
  default     = false
}

variable "create_route53_entry" {
  description = "If set to true, create a DNS A Record for the Tron ALB. Make sure to set var.hosted_zone_id and var.domain_name as well."
  default     = false
}

variable "num_days_after_which_archive_log_data" {
  description = "After this number of days, Tron ALB access logs should be transitioned from S3 to Glacier. Enter 0 to never archive log data."
  default     = 30
}

variable "num_days_after_which_delete_log_data" {
  description = "After this number of days, Tron ALB access logs should be deleted from S3. Enter 0 to never delete log data."
  default     = 0
}

variable "external_account_arn" {
  description = "The ARN of an IAM role in another AWS account you own where your IAM users and groups are defined. This is useful when using ssh-grunt with multiple AWS accounts."
  default     = ""
}

variable "custom_tags" {
  description = "A list of custom tags to apply to Tron and all other resources."
  type        = "map"
  default     = {}
}
