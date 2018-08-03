# vim:set et sw=2 ts=2 foldmethod=marker:

# Relational Database System [MySQL] {{{

resource "random_string" "noticast_web_database_password" {
  length = 24
  special = false
}

resource "aws_db_instance" "main" {
  name = "noticast"
  allocated_storage = 10
  engine = "mysql"
  engine_version = "5.7"
  instance_class = "db.t2.micro"
  username = "noticast_web"
  password = "${random_string.noticast_web_database_password.result}"
  final_snapshot_identifier = "noticast-web-db"
}
# }}}

# EC2 NotiCast Web Application {{{
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

resource "aws_default_vpc" "main" {}
resource "aws_default_subnet" "main" {
  availability_zone = "us-east-2a"
}

resource "random_string" "noticast_web_secret_key" {
  length = 24
  special = true
}

# }}}
