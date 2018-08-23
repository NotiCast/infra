output "api-url" {
  value = "${aws_api_gateway_deployment.messages-api.invoke_url}"
}

output "api-key" {
  value = "${aws_api_gateway_api_key.messages-lambda.value}"
}

output "noticast" {
  value = {
    secret_key = "${random_string.noticast_web_secret_key.result}"
    sqlalchemy_db_uri = "${module.noticast_db_prod.db_uri}"
    stage = "${var.noticast_web_stage}"
    aws = {
      region = "${var.aws_region}"
      access_key = "${aws_iam_access_key.noticast_web.id}"
      secret_key = "${aws_iam_access_key.noticast_web.secret}"
    }
    sentry_dsn = "${var.sentry_dsn_noticast_web}"
  }
}

output "noticast_ips_dev" {
  value = "${module.noticast_web_prod.ec2_addresses}"
}

output "noticast_ips" {
  value = "${aws_instance.noticast_web.*.public_ip}"
}

output "noticast_url" {
  value = "${aws_elb.noticast_web.dns_name}"
}
