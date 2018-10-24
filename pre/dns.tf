provider "aws" {
  region = "us-east-2"
}

variable "bucket_name" {
  type    = "string"
  default = "noticast-messages"
}

variable "domain_name" {
  type    = "string"
  default = "notica.st"
}

# This will need to be changed per-deployment
terraform {
  backend "s3" {
    bucket = "noticast-state"
    key    = "terraform-state"
  }
}

resource "aws_route53_zone" "primary" {
  name = "${var.domain_name}"
}

output "name_servers" {
  value = "${aws_route53_zone.primary.name_servers}"
}
