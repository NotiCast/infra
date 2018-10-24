# vim:set et sw=2 ts=2 foldmethod=marker:

# This will need to be changed per-deployment
terraform {
  backend "s3" {
    bucket = "noticast-state"
    key    = "terraform-state"
  }
}

# route53 configuration {{{
resource "aws_route53_zone" "primary" {
  name = "${var.domain_name}"
}

resource "aws_acm_certificate" "messages-api" {
  domain_name       = "api.${var.domain_name}"
  validation_method = "DNS"
}

resource "aws_route53_record" "messages-api-cert-validation" {
  zone_id = "${aws_route53_zone.primary.zone_id}"
  name    = "${aws_acm_certificate.messages-api.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.messages-api.domain_validation_options.0.resource_record_type}"
  records = ["${aws_acm_certificate.messages-api.domain_validation_options.0.resource_record_value}"]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "messages-api" {
  certificate_arn         = "${aws_acm_certificate.messages-api.arn}"
  validation_record_fqdns = ["${aws_route53_record.messages-api-cert-validation.fqdn}"]
}

resource "aws_api_gateway_domain_name" "messages-api" {
  domain_name = "${aws_acm_certificate.messages-api.domain_name}"

  certificate_arn = "${aws_acm_certificate.messages-api.arn}"

  endpoint_configuration = {
    types = ["EDGE"]
  }
}

resource "aws_route53_record" "messages-api" {
  zone_id = "${aws_route53_zone.primary.zone_id}"
  name    = "${aws_api_gateway_domain_name.messages-api.domain_name}"
  type    = "A"

  alias {
    name                   = "${aws_api_gateway_domain_name.messages-api.cloudfront_domain_name}"
    zone_id                = "${aws_api_gateway_domain_name.messages-api.cloudfront_zone_id}"
    evaluate_target_health = true
  }
}

# }}}

# IoT policy for the devices {{{

data "aws_iam_policy_document" "devices-policy" {
  statement {
    actions = ["s3:Get*", "iot:Publish", "iot:Subscribe", "iot:Connect",
      "iot:Receive",
    ]

    resources = ["*"]
  }
}

resource "aws_iot_policy" "devices-policy" {
  name   = "devices-policy"
  policy = "${data.aws_iam_policy_document.devices-policy.json}"
}

# }}}

# Set up an S3 bucket for storing the mp3s before playing them {{{
resource "aws_s3_bucket" "messages" {
  bucket = "${var.bucket_name}"
  acl    = "public-read"

  lifecycle_rule {
    enabled = true

    expiration {
      days = 1
    }
  }
}

# }}}

module "noticast_db_prod" {
  source = "./modules/noticast_db"

  db_user = "noticast_web"
  db_name = "noticast"
}

module "noticast_web_prod" {
  source = "./modules/noticast_web"

  stage_name = "production"

  server_count           = "3"
  security_group_ids     = ["${aws_default_security_group.main.id}"]
  elb_availability_zones = ["${var.subnet_azs}"]
  ec2_key_name           = "deployer-key"
  domain_name            = "uat.${var.domain_name}"
  route53_zone_id        = "${aws_route53_zone.primary.id}"
  dummy_depends_on       = ["${aws_network_interface.gateway.id}"]
  aws_region             = "${var.aws_region}"
  aws_user               = "noticast_web_production"
}

module "lambda_uat" {
  source = "./modules/lambda"

  stage           = "uat"
  domain_name     = "uat.${var.domain_name}"
  route53_zone_id = "${aws_route53_zone.primary.id}"

  filename           = "message_lambda.zip"
  function_name      = "message_lambda"
  subnet_ids         = ["${aws_subnet.private.id}"]
  security_group_ids = ["${aws_default_security_group.main.id}"]

  db_auth     = "${module.noticast_db_prod.db_username}:${module.noticast_db_prod.db_password}"
  db_name     = "${module.noticast_db_prod.db_name}"
  db_endpoint = "${module.noticast_db_prod.db_endpoint}"
  bucket_name = "${var.bucket_name}"
  email_name  = "${aws_ses_domain_identity.primary.domain}"
  sentry_dsn  = "${var.sentry_dsn_lambda}"
}
