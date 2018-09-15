output "tron_asg_name" {
  value = "${element(module.tron.server_asg_names, 0)}"
}

output "tron_asg_id" {
  value = "${element(module.tron.server_asg_ids, 0)}"
}

output "tron_security_group_id" {
  value = "${module.tron.security_group_id}"
}

output "tron_iam_role_id" {
  value = "${module.tron.iam_role_id}"
}

output "tron_iam_role_arn" {
  value = "${module.tron.iam_role_arn}"
}

output "tron_ebs_volume_id" {
  value = "${element(module.tron.ebs_volume_ids, 0)}"
}

output "tron_eni_id" {
  value = "${element(module.tron.eni_ids, 0)}"
}

output "alb_name" {
  value = "${module.alb.alb_name}"
}

output "alb_arn" {
  value = "${module.alb.alb_arn}"
}

output "alb_dns_name" {
  value = "${module.alb.alb_dns_name}"
}

output "alb_hosted_zone_id" {
  value = "${module.alb.alb_hosted_zone_id}"
}

output "alb_security_group_id" {
  value = "${module.alb.alb_security_group_id}"
}

output "alb_listener_arns" {
  value = "${module.alb.listener_arns}"
}

output "alb_http_listener_arns" {
  value = "${module.alb.http_listener_arns}"
}

output "alb_https_listener_non_acm_cert_arns" {
  value = "${module.alb.https_listener_non_acm_cert_arns}"
}

output "alb_https_listener_acm_cert_arns" {
  value = "${module.alb.https_listener_acm_cert_arns}"
}

output "tron_domain_name" {
  value = "${var.create_route53_entry ? element(concat(aws_route53_record.tron.*.fqdn, list("")), 0) : module.alb.alb_dns_name}"
}
