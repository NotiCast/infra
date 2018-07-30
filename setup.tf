# vim:set et sw=2 ts=2 foldmethod=marker:

# This will need to be changed per-deployment
terraform {
  backend "s3" {
    bucket = "noticast-state"
    key = "terraform-state"
  }
}

# Variables {{{
variable "aws_region" {
  type = "string"
  default = "us-east-2"
}

provider "aws" {
  region = "${var.aws_region}"
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

# }}}

# {{{ REST API access point

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

/*
# route53 configuration {{{
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
# }}}
*/

# lambda configuration {{{

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

# Relational Database System [MySQL] {{{
resource "aws_db_instance" "main" {
  allocated_storage    = 10
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  username             = "testing"
  password             = "herpderp"
}
# }}}

# Elastic Beanstalk Application {{{
data "aws_iam_policy_document" "noticast_web" {
  statement {
    # Actions {{{
    actions = [
      "iot:AddThingToThingGroup",
      "iot:AttachPolicy",
      "iot:AttachThingPrincipal",
      "iot:CreateKeysAndCertificate",
      "iot:CreateThing",
      "iot:CreateThingGroup",
      "iot:DeleteCertificate",
      "iot:DeleteThing",
      "iot:DeleteThingGroup",
      "iot:DetachThingPrincipal",
      "iot:DescribeEndpoint",
      "iot:DescribeThing",
      "iot:DescribeThingGroup",
      "iot:ListCertificates",
      "iot:ListThings",
      "iot:ListThingGroups",
      "iot:ListThingsInThingGroup",
      "iot:ListThingGroupsForThing",
      "iot:ListThingPrincipals",
      "iot:Publish",
      "iot:RemoveThingFromThingGroup",
      "iot:UpdateThing",
      "iot:UpdateCertificate",
      "iot:UpdateThingGroup",
      "iot:UpdateThingGroupsForThing"
    ]
    # }}}
    resources = ["*"]
  }
}

resource "aws_iam_policy" "noticast_web" {
  policy = "${data.aws_iam_policy_document.noticast_web.json}"
}

resource "aws_iam_user" "noticast_web" {
  name = "noticast_web"
}

resource "aws_iam_access_key" "noticast_web" {
  user = "${aws_iam_user.noticast_web.name}"
}

resource "aws_iam_user_policy_attachment" "noticast_web" {
  user = "${aws_iam_user.noticast_web.name}"
  policy_arn = "${aws_iam_policy.noticast_web.arn}"
}

/*
resource "aws_elastic_beanstalk_application" "noticast_web" {
  name = "noticast_web"
  description = "NotiCast website"
}

resource "aws_elastic_beanstalk_environment" "noticast_web" {
  application = "noticast_web"
  cname_prefix = "app"

  solution_stack_name = "64bit Amazon Linux 2016.09 v2.5.2 running Docker 1.12.6"

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name = "AWS_ACCESS_KEY_ID"
    value = "${aws_iam_access_key.noticast_web.id}"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name = "AWS_SECRET_KEY_ID"
    value = "${aws_iam_access_key.noticast_web.secret}"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name = "AWS_DEFAULT_REGION"
    value = "${var.aws_region}"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name = "SECRET_KEY"
    value = "${var.aws_region}"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name = "SQLALCHEMY_DATABASE_URI"
    value = "msyql+pymysql://${aws_db_instance.main.username}:${aws_db_instance.main.password}@${aws_db_instance.main.endpoint}/${aws_db_instance.main.name}"
  }
}
*/
# }}}

output "api-url" {
  value = "${aws_api_gateway_deployment.messages-api.invoke_url}"
}

output "api-key" {
  value = "${aws_api_gateway_api_key.messages-lambda.value}"
}
