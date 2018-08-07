# vim:set et sw=2 ts=2 foldmethod=marker:

# {{{ Rest API
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

# }}}

# {{{ Lambda

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
}

# }}}

# API key and deployment setup {{{

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

# }}}
