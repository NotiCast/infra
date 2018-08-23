# vim:set et sw=2 ts=2 foldmethod=marker:

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

resource "random_string" "noticast_web_secret_key" {
  length = 24
  special = true
}

data "aws_ami" "debian_stretch" {
  most_recent = true

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name = "name"
    values = ["debian-stretch-hvm-x86_64-*"]
  }

  owners = ["379101102735"]
}

resource "aws_instance" "noticast_web" {
  count = "${var.noticast_web_server_count}"
  # FQDN
  ami = "${data.aws_ami.debian_stretch.id}"

  vpc_security_group_ids = ["${aws_default_security_group.main.id}"]
  key_name = "deployer-key"
  associate_public_ip_address = true

  instance_type = "t2.micro"

  tags = {
    Name = "node${count.index}.nodes.${var.domain_name}"
  }

  depends_on = ["aws_network_interface.gateway"]
}
# }}}

# TLS Terminator / Load Balancer {{{
resource "aws_elb" "noticast_web" {
  availability_zones = "${var.subnet_azs}"
  security_groups = ["${aws_default_security_group.main.id}"]

  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 443
    lb_protocol = "https"
    ssl_certificate_id = "${aws_acm_certificate_validation.noticast_web.certificate_arn}"
  }

  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  instances = ["${aws_instance.noticast_web.*.id}"]
  cross_zone_load_balancing = true
}

resource "aws_route53_record" "noticast-vms" {
  count = "${var.noticast_web_server_count}"
  zone_id = "${aws_route53_zone.primary.zone_id}"
  name = "${element(aws_instance.noticast_web.*.tags.Name, count.index)}"
  type = "A"
  records = ["${element(aws_instance.noticast_web.*.public_ip, count.index)}"]
  ttl = "60"
}

resource "aws_route53_record" "noticast_web" {
  zone_id = "${aws_route53_zone.primary.zone_id}"
  name = "${var.domain_name}"
  type = "A"

  alias {
    name = "${aws_elb.noticast_web.dns_name}"
    zone_id = "${aws_elb.noticast_web.zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_acm_certificate" "noticast_web" {
  domain_name = "${var.domain_name}"
  validation_method = "DNS"
}

resource "aws_route53_record" "noticast_web-cert-validation" {
  zone_id = "${aws_route53_zone.primary.zone_id}"
  name = "${aws_acm_certificate.noticast_web.domain_validation_options.0.resource_record_name}"
  type = "${aws_acm_certificate.noticast_web.domain_validation_options.0.resource_record_type}"

  records = ["${aws_acm_certificate.noticast_web.domain_validation_options.0.resource_record_value}"]
  ttl = 60
}

resource "aws_acm_certificate_validation" "noticast_web" {
  certificate_arn = "${aws_acm_certificate.noticast_web.arn}"
  validation_record_fqdns = ["${aws_route53_record.noticast_web-cert-validation.fqdn}"]
}
# }}}
