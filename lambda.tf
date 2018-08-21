# vim:set et sw=2 ts=2 foldmethod=marker:

# {{{ Rest API
resource "aws_api_gateway_rest_api" "messages-api" {
  name = "messages-api"

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

resource "aws_api_gateway_integration" "messages-lambda" {
  rest_api_id = "${aws_api_gateway_rest_api.messages-api.id}"
  resource_id = "${aws_api_gateway_resource.messages-endpoint.id}"
  http_method = "${aws_api_gateway_method.messages-endpoint-method.http_method}"
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = "${aws_lambda_function.message-lambda.invoke_arn}"

  depends_on = ["aws_lambda_permission.gateway-lambda-permission"]
}

# }}}

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
    # I just flat out don't know what's required, so...
    actions = ["iot:Publish", "s3:*", "polly:*", "cloudwatch:*", "logs:*"]
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

  vpc_config {
    subnet_ids = ["${aws_subnet.private.id}"]
    security_group_ids = ["${aws_default_security_group.main.id}"]
  }

  environment {
    variables = {
      sqlalchemy_db_endpoint = "${aws_db_instance.main.endpoint}"
      sqlalchemy_db_auth = "${aws_db_instance.main.username}:${aws_db_instance.main.password}"
      sqlalchemy_db_name = "${aws_db_instance.main.name}"
      messages_bucket = "${var.bucket_name}"
      email_domain = "${aws_ses_domain_identity.primary.domain}"
    }
  }
}

# }}}

# API key and deployment setup {{{

resource "aws_api_gateway_api_key" "messages-lambda" {
  name = "master-key-2"
}

resource "aws_api_gateway_deployment" "messages-api" {
  depends_on = ["aws_api_gateway_integration.messages-lambda"]
  rest_api_id = "${aws_api_gateway_rest_api.messages-api.id}"
  stage_name  = "${aws_api_gateway_usage_plan.master.api_stages.0.stage}"
}

/*
resource "aws_api_gateway_base_path_mapping" "messages-api" {
  depends_on = ["aws_api_gateway_domain_name.messages-api"]
  api_id = "${aws_api_gateway_rest_api.messages-api.id}"
  stage_name = "${aws_api_gateway_deployment.messages-api.stage_name}"
  domain_name = "${aws_api_gateway_domain_name.messages-api.domain_name}"
}
*/

resource "aws_api_gateway_usage_plan" "master" {
  name = "master_plan"

  api_stages {
    api_id = "${aws_api_gateway_rest_api.messages-api.id}"
    stage = "test"
  }
}

resource "aws_api_gateway_usage_plan_key" "master" {
  key_id = "${aws_api_gateway_api_key.messages-lambda.id}"
  key_type = "API_KEY"
  usage_plan_id = "${aws_api_gateway_usage_plan.master.id}"
}

# }}}
