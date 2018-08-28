# vim:set et sw=2 ts=2 foldmethod=marker:

# {{{ Lambda
resource "aws_lambda_permission" "gateway-lambda-permission" {
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.message-lambda.arn}"
  principal = "apigateway.amazonaws.com"
}

resource "aws_lambda_permission" "ses-lambda-permission" {
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.message-lambda.arn}"
  principal = "ses.amazonaws.com"
}

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
  name = "lambda-aws-${var.stage}"
  assume_role_policy = "${data.aws_iam_policy_document.lambda-aws-role-policy.json}"
}

data "aws_iam_policy_document" "lambda-aws-policy" {
  statement {
    actions = ["iot:Publish", "s3:*", "polly:*", "cloudwatch:*", "logs:*", "ec2:*"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lambda-aws-policy" {
  name = "lambda-aws-policy-${var.stage}"
  policy = "${data.aws_iam_policy_document.lambda-aws-policy.json}"
}

resource "aws_iam_role_policy_attachment" "lambda-aws-role-policy" {
  role = "${aws_iam_role.lambda-aws-role.name}"
  policy_arn = "${aws_iam_policy.lambda-aws-policy.arn}"
}

resource "aws_lambda_function" "message-lambda" {
  filename = "${var.filename}"
  function_name = "${var.function_name}-${var.stage}"
  role = "${aws_iam_role.lambda-aws-role.arn}"
  handler = "lambda_function.lambda_handler"
  source_code_hash = "${base64sha256(file(var.filename))}"
  runtime = "python3.6"

  vpc_config {
    subnet_ids = ["${var.subnet_ids}"]
    security_group_ids = ["${var.security_group_ids}"]
  }

  environment {
    variables = {
      sqlalchemy_db_endpoint = "${var.db_endpoint}"
      sqlalchemy_db_auth = "${var.db_auth}"
      sqlalchemy_db_name = "${var.db_name}"
      messages_bucket = "${var.bucket_name}"
      email_domain = "${var.email_name}"
      raven_endpoint = "${var.sentry_dsn}"
    }
  }
}
# }}}

# {{{ Rest API
resource "aws_api_gateway_rest_api" "messages-api" {
  name = "messages-api-${var.stage}"

  endpoint_configuration = {
    types = ["EDGE"]
  }
}

resource "aws_api_gateway_resource" "messages-endpoint" {
  rest_api_id = "${aws_api_gateway_rest_api.messages-api.id}"
  parent_id = "${aws_api_gateway_rest_api.messages-api.root_resource_id}"
  path_part = "send_message"
}

resource "aws_api_gateway_method" "messages-endpoint-method" {
  rest_api_id = "${aws_api_gateway_rest_api.messages-api.id}"
  resource_id = "${aws_api_gateway_resource.messages-endpoint.id}"
  http_method = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "messages-api" {
  rest_api_id = "${aws_api_gateway_rest_api.messages-api.id}"
  resource_id = "${aws_api_gateway_resource.messages-endpoint.id}"
  http_method = "${aws_api_gateway_method.messages-endpoint-method.http_method}"
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = "${aws_lambda_function.message-lambda.invoke_arn}"

  depends_on = ["aws_lambda_permission.gateway-lambda-permission"]
}
# }}}

# DNS setup {{{
resource "aws_acm_certificate" "messages-api" {
  domain_name = "api.${var.domain_name}"
  validation_method = "DNS"
}

resource "aws_route53_record" "messages-api-cert-validation" {
  zone_id = "${var.route53_zone_id}"
  name = "${aws_acm_certificate.messages-api.domain_validation_options.0.resource_record_name}"
  type = "${aws_acm_certificate.messages-api.domain_validation_options.0.resource_record_type}"
  records = ["${aws_acm_certificate.messages-api.domain_validation_options.0.resource_record_value}"]
  ttl = 60
}

resource "aws_acm_certificate_validation" "messages-api" {
  certificate_arn = "${aws_acm_certificate.messages-api.arn}"
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
  zone_id = "${var.route53_zone_id}"
  name = "${aws_api_gateway_domain_name.messages-api.domain_name}"
  type = "A"

  alias {
    name = "${aws_api_gateway_domain_name.messages-api.cloudfront_domain_name}"
    zone_id = "${aws_api_gateway_domain_name.messages-api.cloudfront_zone_id}"
    evaluate_target_health = true
  }
}
# }}}

# Deployment {{{

resource "aws_api_gateway_deployment" "messages-api" {
  depends_on = ["aws_api_gateway_integration.messages-api"]
  rest_api_id = "${aws_api_gateway_rest_api.messages-api.id}"
  stage_name = "${var.stage}"
}

resource "aws_api_gateway_base_path_mapping" "messages-api" {
  api_id = "${aws_api_gateway_rest_api.messages-api.id}"
  stage_name = "${aws_api_gateway_deployment.messages-api.stage_name}"
  domain_name = "${aws_api_gateway_domain_name.messages-api.domain_name}"

  depends_on = ["aws_api_gateway_domain_name.messages-api"]
}
# }}}
