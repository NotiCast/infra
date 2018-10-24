output "aws_info" {
  value = {
    region     = "${var.aws_region}"
    access_key = "${aws_iam_access_key.noticast_web.id}"
    secret_key = "${aws_iam_access_key.noticast_web.secret}"
  }
}

output "secret_key" {
  value = "${random_string.secret_key.result}"
}

output "ec2_addresses" {
  value = "${aws_route53_record.noticast-vms.*.fqdn}"
}

output "elb_name" {
  value = "${aws_route53_record.noticast_web.fqdn}"
}

output "stage_name" {
  value = "${var.stage_name}"
}
