resource "aws_ses_domain_identity" "primary" {
  domain = "${var.incoming_email_subdomain}.${var.domain_name}"
}

resource "aws_route53_record" "ses-verification" {
  zone_id = "${aws_route53_zone.primary.id}"
  name = "_amazonses.${var.incoming_email_subdomain}.${var.domain_name}"
  type = "TXT"
  ttl = "600"
  records = ["${aws_ses_domain_identity.primary.verification_token}"]
}

resource "aws_route53_record" "ses-incoming" {
  zone_id = "${aws_route53_zone.primary.id}"
  name = "${var.incoming_email_subdomain}.${var.domain_name}"
  type = "MX"
  ttl = "60"
  records = ["1 INBOUND-SMTP.US-EAST-1.AMAZONAWS.COM"]
}

resource "aws_route53_record" "ses-spf" {
  zone_id = "${aws_route53_zone.primary.id}"
  name = "@"
  type = "TXT"
  ttl = "60"
  records = ["v=spf1 include:amazonecs.com ~all"]
}

resource "aws_ses_receipt_rule_set" "default" {
  rule_set_name = "default-rule-set"
}

resource "aws_ses_active_receipt_rule_set" "default" {
  rule_set_name = "${aws_ses_receipt_rule_set.default.rule_set_name}"
}

resource "aws_ses_receipt_rule" "fallback" {
  name = "mailgun"
  rule_set_name = "${aws_ses_receipt_rule_set.default.rule_set_name}"
  recipients = ["send.noticast.io"]
  enabled = true

  lambda_action {
    function_arn = "${aws_lambda_function.message-lambda.arn}"
    position = "1"
  }

  depends_on = ["aws_lambda_permission.ses-lambda-permission"]
}
