# ----------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables must be passed in by the templates using this module.
# ----------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "The name for the Tron ASG and to namespace all the resources created by this module."
}

variable "aws_region" {
  description = "The AWS region to deploy to (e.g. us-east-1)."
}

variable "aws_account_id" {
  description = "The ID of the AWS account to deploy to."
}

variable "environment_name" {
  description = "The name of the environment we're in (e.g., stage, prod, mgmt)."
}

variable "ami_id" {
  description = "The ID of the Amazon Machine Image (AMI) to run for Tron (e.g., ami-abcd1234)."
}

variable "instance_type" {
  description = "The type of EC2 Instance to run (e.g. t2.micro)."
}

variable "vpc_id" {
  description = "The id of the VPC where Tron should be deployed (e.g. vpc-abcd1234)."
}

variable "tron_subnet_id" {
  description = "The ID of the subnet where Tron should be deployed (e.g., subnet-abcd1234)."
}

variable "alb_subnet_ids" {
  description = "The IDs of the subnets where the Tron ALB should be deployed (e.g., subnet-abcd1234)."
  type        = "list"
}

variable "user_data" {
  description = "The User Data script to run on the Tron server when it's booting."
}

variable "acm_cert_domain_name" {
  description = "The domain name for which there is an ACM cert in this region that can be used to do SSL termination for the Tron ALB (e.g. *.foo.com)."
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

variable "num_days_after_which_archive_log_data" {
  description = "After this number of days, Tron ALB access logs should be transitioned from S3 to Glacier. Enter 0 to never archive log data."
  default     = 30
}

variable "num_days_after_which_delete_log_data" {
  description = "After this number of days, Tron ALB access logs should be deleted from S3. Enter 0 to never delete log data."
  default     = 0
}

variable "skip_rolling_deploy" {
  description = "If set to true, skip the rolling deployment, and destroy all the servers immediately. You should typically NOT enable this in prod, as it will cause downtime! The main use case for this flag is to make testing and cleanup easier. It can also be handy in case the rolling deployment code has a bug."
  default     = false
}

variable "allow_incoming_http_from_cidr_blocks" {
  description = "The CIDR blocks from which the Tron ALB will allow HTTP/HTTPS requests. At least one of allow_incoming_http_from_cidr_blocks or allow_incoming_http_from_security_group_ids must be non-empty, or the ALB won't be able to receive any requests!"
  type        = "list"
  default     = []
}

variable "allow_incoming_http_from_security_group_ids" {
  description = "The Security Group IDs from which the Tron ALB will allow HTTP/HTTPS requests. At least one of allow_incoming_http_from_cidr_blocks or allow_incoming_http_from_security_group_ids must be non-empty, or the ALB won't be able to receive any requests!"
  type        = "list"
  default     = []
}

variable "create_route53_entry" {
  description = "If set to true, create a DNS A Record for the Tron ALB. Make sure to set var.hosted_zone_id and var.domain_name as well."
  default     = false
}

variable "hosted_zone_id" {
  description = "The ID of the Route 53 Hosted Zone in which to create a DNS A Record. Only used if var.create_route53_entry is true."
  default     = "replace-me"
}

variable "domain_name" {
  description = "The domain name for which to create a DNS A Record (e.g., foo.tron.com). Only used if var.create_route53_entry is true."
  default     = "replace-me"
}

variable "key_pair_name" {
  description = "The name of an EC2 Key Pair to associate with each server for SSH access. Set to an empty string to not associate a Key Pair."
  default     = ""
}

variable "allow_ssh_from_cidr_blocks" {
  description = "A list of IP address ranges in CIDR format from which SSH access will be permitted. Attempts to access the bastion host from all other IP addresses will be blocked."
  type        = "list"
  default     = []
}

variable "allow_ssh_from_security_group_ids" {
  description = "The IDs of security groups from which SSH connections will be allowed."
  type        = "list"
  default     = []
}

variable "deployment_batch_size" {
  description = "How many servers to deploy at a time during a rolling deployment. For example, if you have 10 servers and set this variable to 2, then the deployment will a) undeploy 2 servers, b) deploy 2 replacement servers, c) repeat the process for the next 2 servers."
  default     = 1
}

variable "wait_for_capacity_timeout" {
  description = "A maximum duration to wait for each server to be healthy before timing out (e.g. 10m). Valid units of time are: s, m, h."
  default     = "10m"
}

variable "custom_tags" {
  description = "A list of custom tags to apply to Tron and all other resources."
  type        = "map"
  default     = {}
}

variable "tenancy" {
  description = "The tenancy to use for Tron. Must be one of: default, dedicated, or host."
  default     = "default"
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

variable "script_log_level" {
  description = "The log level to use with the rolling deploy script. It can be useful to set this to DEBUG when troubleshooting Tron redeploys."
  default     = "INFO"
}

variable "skip_health_check" {
  description = "If set to true, skip the health check, and start a rolling deployment of Tron without waiting for it to initially be in a healthy state. This is primarily useful if the server group is in a broken state and you want to force a deployment anyway."
  default     = false
}

variable "health_check_type" {
  description = "The type of health check to use. Must be one of: EC2 or ELB. If you associate any load balancers with this server group via var.elb_names or var.alb_target_group_arns, you should typically set this parameter to ELB."
  default     = "EC2"
}

variable "health_check_protocol" {
  description = "TThe protocol to use to connect with the target."
  default     = "HTTP"
}

variable "tron_node_http_health_check_path" {
  description = "The path for the node health check"
  default     = "/"
}

variable "tron_solidity_http_health_check_path" {
  description = "The path for the solidity health check"
  default     = "/"
}

variable "health_check_matcher" {
  description = "The HTTP codes to use when checking for a successful response from a target. You can specify multiple values (for example, 200,202) or a range of values (for example, 200-299). Applies to Application Load Balancers only (HTTP/HTTPS)"
  default     = "200"
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
  description = "The path on the Tron server the ALB should use for health checks."
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

variable "alb_target_group_stickiness_enabled" {
  description = "Stickiness is only valid if used with Load Balancers of type Application"
  default     = true
}

variable "alb_target_group_stickiness_type" {
  description = "The type of sticky sessions. The only current possible value is lb_cookie"
  default     = "lb_cookie"
}

variable "alb_target_group_stickiness_cookie_duration" {
  description = "The time period, in seconds, during which requests from a client should be routed to the same target. After this time period expires, the load balancer-generated cookie is considered stale. The range is 1 second to 1 week (604800 seconds). The default value is 1 day (86400 seconds)"
  default     = 86400
}

variable "is_internal_alb" {
  description = "Set to true to make the Tron ALB an internal ALB that cannot be accessed from the public Internet."
  default     = true
}

variable "num_enis" {
  description = "The number of extra Elastic Network Interfaces (ENIs) to create for server. Each ENI is an IP address that will remain static, even if the underlying server is replaced. Each ENI and server pair will get matching tags with a name of the format eni-xxx, where xxx is the index of the ENI (e.g., eni-0, eni-1, etc). These tags can be used by each server to find and mount its ENI(s)."
  default     = 0
}

# Optional DNS records

variable "route53_hosted_zone_id" {
  description = "The ID of the Route53 Hosted Zone in which we will create the DNS records specified by var.dns_name_common_portion. Only used if var.dns_name_common_portion is non-empty."
  default     = ""
}

variable "dns_name_common_portion" {
  description = "The common portion of the DNS name to assign to each server. For example, if you want DNS records eni-0.0.foo, eni-0.1.foo, eni-0.2.foo, etc., use the value 'foo' and set var.num_enis to 1. A unique DNS records will be created for each combination of an ENI and server. Note that this value must be a valid record name for the Route 53 Hosted Zone ID specified in var.route53_hosted_zone_id. This var is overriden by var.dns_names if that var is non-empty. Examples: kafka.aws or kafka.acme.com."
  default     = ""
}

variable "dns_name" {
  description = "A list of DNS names to assign to each ENI in the Server Group. Make sure the list has n entries, where n = var.num_enis * var.size. If this var is specified, it will override var.dns_name_common_portion. Example: [0.acme.com, 1.acme.com, 2.acme.com]"
  default     = ""
}
