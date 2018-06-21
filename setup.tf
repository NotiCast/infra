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

/*
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
*/

resource "aws_lambda_permission" "messages-lambda" {
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.message-lambda.arn}"
  principal = "apigateway.amazonaws.com"
}

# IAM role and policy for the lambda

data "aws_iam_policy_document" "lambda-aws-role-policy" {
  statement {
    principals {
      type = "Service",
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda-aws-role" {
  name = "lambda-aws"
  assume_role_policy = "${data.aws_iam_policy_document.lambda-aws-role-policy.json}"
}

data "aws_iam_policy_document" "lambda-aws-policy" {
  statement {
    actions = ["iot:Publish", "s3:*", "polly:*"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lambda-aws-policy" {
  name = "lambda-aws-policy"
  policy = "${data.aws_iam_policy_document.lambda-aws-policy.json}"
}

resource "aws_iam_role_policy_attachment" "lambda-aws-role-policy" {
  role = "${aws_iam_role.lambda-aws-role.name}"
  policy_arn = "${aws_iam_policy.lambda-aws-policy.arn}"
}

# The lambda for signalling devices

resource "aws_lambda_function" "message-lambda" {
  filename = "message_lambda.zip"
  function_name = "message_lambda"
  role = "${aws_iam_role.lambda-aws-role.arn}"
  handler = "lambda_function.lambda_handler"
  source_code_hash = "${base64sha256(file("message_lambda.zip"))}"
  runtime = "python3.6"
}

# IoT policy for the devices
# Since Terraform doesn't have good AWS IoT support... JSON in a heredoc.

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

# Set up notifications, sent by lambda, received by IoT devices

resource "aws_sns_topic" "play-message" {
  name = "play-message"
}

# Set up an S3 bucket for storing the mp3s before playing them

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

# Set up and print out an API key for the lambda

resource "aws_api_gateway_api_key" "messages-lambda" {
  provider = "aws.edge"
  name = "master-key-2"
}

resource "aws_api_gateway_deployment" "messages-api" {
  provider = "aws.edge"

  depends_on = ["aws_api_gateway_integration.messages-lambda"]
  rest_api_id = "${aws_api_gateway_rest_api.messages-api.id}"
  stage_name  = "test"
}

/*
resource "aws_api_gateway_base_path_mapping" "messages-api" {
  provider = "aws.edge"

  depends_on = ["aws_api_gateway_domain_name.messages-api"]
  api_id = "${aws_api_gateway_rest_api.messages-api.id}"
  stage_name = "${aws_api_gateway_deployment.messages-api.stage_name}"
  domain_name = "${aws_api_gateway_domain_name.messages-api.domain_name}"
}
*/

resource "aws_api_gateway_usage_plan" "master" {
  provider = "aws.edge"
  name = "master_plan"

  api_stages {
    api_id = "${aws_api_gateway_rest_api.messages-api.id}"
    stage = "${aws_api_gateway_deployment.messages-api.stage_name}"
  }
}

resource "aws_api_gateway_usage_plan_key" "master" {
  provider = "aws.edge"
  key_id = "${aws_api_gateway_api_key.messages-lambda.id}"
  key_type = "API_KEY"
  usage_plan_id = "${aws_api_gateway_usage_plan.master.id}"
}

output "api-url" {
  value = "${aws_api_gateway_deployment.messages-api.invoke_url}"
}

output "api-key" {
  value = "${aws_api_gateway_api_key.messages-lambda.value}"
}
