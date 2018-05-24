provider "aws" {
  region = "us-east-2"
}

variable "bucket_name" {
  type = "string"
  default = "noticast-messages"
}

variable "root_name" {
  type = "string"
  default = "notica.st"
}

variable "domain_name" {
  type = "string"
  default = "api.notica.st"
}

# This will need to be changed per-deployment
terraform {
  backend "s3" {
    bucket = "noticast-state"
    key = "terraform-state"
  }
}

# REST API access point

provider "aws" {
  region = "us-east-1"
  alias = "edge"
}

resource "aws_api_gateway_rest_api" "messages-api" {
  provider = "aws.edge"
  name = "messages-api"

  endpoint_configuration = {
    types = ["EDGE"]
  }
}

resource "aws_api_gateway_resource" "messages-endpoint" {
  provider = "aws.edge"

  rest_api_id = "${aws_api_gateway_rest_api.messages-api.id}"
  parent_id = "${aws_api_gateway_rest_api.messages-api.root_resource_id}"
  path_part = "send_message"
}

resource "aws_api_gateway_method" "messages-endpoint-method" {
  provider = "aws.edge"

  rest_api_id = "${aws_api_gateway_rest_api.messages-api.id}"
  resource_id = "${aws_api_gateway_resource.messages-endpoint.id}"
  http_method = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "messages-lambda" {
  provider = "aws.edge"

  rest_api_id = "${aws_api_gateway_rest_api.messages-api.id}"
  resource_id = "${aws_api_gateway_resource.messages-endpoint.id}"
  http_method = "${aws_api_gateway_method.messages-endpoint-method.http_method}"
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = "${aws_lambda_function.message-lambda.invoke_arn}"
}

resource "aws_route53_zone" "primary" {
  name = "${var.root_name}"
}

resource "aws_route53_record" "messages-api" {
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
  domain_name = "${var.domain_name}"

  certificate_arn = "${aws_acm_certificate.messages-api.arn}"
  endpoint_configuration = {
    types = ["EDGE"]
  }
}

resource "aws_lambda_permission" "messages-lambda" {
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.message-lambda.arn}"
  principal = "apigateway.amazonaws.com"
}

# IAM role and policy for the lambda

data "aws_iam_policy_document" "lambda-sns-role-policy" {
  statement {
    principals {
      type = "Service",
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda-sns-role" {
  name = "lambda-sns"
  assume_role_policy = "${data.aws_iam_policy_document.lambda-sns-role-policy.json}"
}

data "aws_iam_policy_document" "lambda-sns-policy" {
  statement {
    actions = ["sns:Publish"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lambda-sns-policy" {
  name = "lambda-sns-policy"
  policy = "${data.aws_iam_policy_document.lambda-sns-policy.json}"
}

resource "aws_iam_role_policy_attachment" "lambda-sns-role-policy" {
  role = "${aws_iam_role.lambda-sns-role.name}"
  policy_arn = "${aws_iam_policy.lambda-sns-policy.arn}"
}

# The lambda for signalling devices

resource "aws_lambda_function" "message-lambda" {
  filename = "message_lambda.zip"
  function_name = "message_lambda"
  role = "${aws_iam_role.lambda-sns-role.arn}"
  handler = "lambda_function.lambda_handler"
  source_code_hash = "${base64sha256("message_lambda.zip")}"
  runtime = "python3.6"
}

# IoT policy for the devices
# Since Terraform doesn't have good AWS IoT support... JSON in a heredoc.

data "aws_iam_policy_document" "devices-policy" {
  statement {
    actions = ["s3:Get*", "sns:Subscribe", "sns:Unsubscribe"]
    resources = ["arn:aws:s3:::noticast-messages/*.mp3"]
  }
}

resource "aws_iot_policy" "devices-policy" {
  name = "devices-policy"
  policy = "${data.aws_iam_policy_document.devices-policy.json}"
}

# Set up notifications, sent by lambda, received by IoT devices

resource "aws_sns_topic" "play-message" {
  name = "play-message"
}

# Set up an S3 bucket for storing the mp3s before playing them

resource "aws_s3_bucket" "messages" {
  bucket = "${var.bucket_name}"
}
