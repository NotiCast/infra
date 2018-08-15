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

variable "domain_name" {
  type = "string"
  default = "noticast.io"
}

variable "noticast_web_stage" {
  type = "string"
  default = "development"
}

variable "noticast_web_stage_domain_name" {
  type = "string"
  default = "dev"
}

variable "noticast_shell_server_deploy_key" {
  type = "string"
  default = "Ryan-Yubikey"
}

variable "noticast_web_server_count" {
  type = "string"
  default = "3"
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

variable "sentry_dsn_noticast_web" {
  type = "string"
  default = "https://e9a4a3c273a6470c8ded06978dae8112:13a7e4334a0e413d91d7d7958300d68f@sentry.io/1261427"
}
