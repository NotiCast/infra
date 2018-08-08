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

variable "subnet_azs" {
  type = "list"
  default = ["us-east-2a", "us-east-2b", "us-east-2c"]
}

variable "vpc_cidr" {
  type = "string"
  default = "172.31.0.0/16"
}

variable "private_subnet_cidr" {
  type = "string"
  default = "172.31.48.0/20"
}

variable "private_subnet_ips" {
  type = "list"
  default = ["172.31.17.161"]  # who knows that's what they gave me
}
