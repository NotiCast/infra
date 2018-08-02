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

variable "noticast_web_stage" {
  type = "string"
  default = "development"
}
