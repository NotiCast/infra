# vim:set et sw=2 ts=2 foldmethod=marker:

# This will need to be changed per-deployment
terraform {
  backend "s3" {
    bucket = "noticast-state"
    key = "terraform-state"
  }
}


# route53 configuration {{{
resource "aws_route53_zone" "primary" {
  name = "${var.domain_name}"
}

/*
resource "aws_route53_record" "messages-api" {
  provider = "aws.edge"

  zone_id = "${aws_route53_zone.primary.zone_id}"
  name = "${aws_api_gateway_domain_name.messages-api.domain_name}"
  type = "A"

  alias {
    name = "${aws_api_gateway_domain_name.messages-api.cloudfront_domain_name}"
    zone_id = "${aws_api_gateway_domain_name.messages-api.cloudfront_zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "messages-api-cert-validation" {
  zone_id = "${aws_route53_zone.primary.zone_id}"
  name = "${aws_acm_certificate.messages-api.domain_validation_options.0.resource_record_name}"
  type = "${aws_acm_certificate.messages-api.domain_validation_options.0.resource_record_type}"
  records = ["${aws_acm_certificate.messages-api.domain_validation_options.0.resource_record_value}"]
  ttl = 60
}

resource "aws_acm_certificate" "messages-api" {
  provider = "aws.edge"

  domain_name = "${var.domain_name}"
  validation_method = "DNS"
}

resource "aws_acm_certificate_validation" "messages-api" {
  provider = "aws.edge"

  certificate_arn = "${aws_acm_certificate.messages-api.arn}"
  validation_record_fqdns = ["${aws_route53_record.messages-api-cert-validation.fqdn}"]
}

resource "aws_route53_record" "cert_validation" {
  name = "${aws_acm_certificate.messages-api.domain_validation_options.0.resource_record_name}"
  type = "${aws_acm_certificate.messages-api.domain_validation_options.0.resource_record_type}"
  zone_id = "${aws_route53_zone.primary.id}"
  records = ["${aws_acm_certificate.messages-api.domain_validation_options.0.resource_record_value}"]
  ttl = 60
}

resource "aws_api_gateway_domain_name" "messages-api" {
  provider = "aws.edge"

  domain_name = "${var.domain_name}"

  certificate_arn = "${aws_acm_certificate.messages-api.arn}"
  endpoint_configuration = {
    types = ["EDGE"]
  }
}
# }}}
*/

# IoT policy for the devices {{{

data "aws_iam_policy_document" "devices-policy" {
  statement {
    actions = ["s3:Get*", "iot:Publish", "iot:Subscribe", "iot:Connect",
               "iot:Receive"]
    resources = ["*"]
  }
}

resource "aws_iot_policy" "devices-policy" {
  name = "devices-policy"
  policy = "${data.aws_iam_policy_document.devices-policy.json}"
}

# }}}

# Set up notifications, sent by lambda, received by IoT devices {{{
resource "aws_sns_topic" "play-message" {
  name = "play-message"
}
# }}}

# Set up an S3 bucket for storing the mp3s before playing them {{{
resource "aws_s3_bucket" "messages" {
  bucket = "${var.bucket_name}"
  acl = "public-read"

  lifecycle_rule {
    enabled = true

    expiration {
      days = 1
    }
  }
}
# }}}
