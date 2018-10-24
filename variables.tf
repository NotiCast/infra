variable "aws_region" {
  type    = "string"
  default = "us-east-1"
}

provider "aws" {
  region = "${var.aws_region}"
}

variable "bucket_name" {
  type    = "string"
  default = "noticast-outgoing-messages"
}

variable "domain_name" {
  type    = "string"
  default = "noticast.io"
}

variable "incoming_email_subdomain" {
  type    = "string"
  default = "send"
}

variable "noticast_web_stage" {
  type    = "string"
  default = "production"
}

variable "noticast_web_stage_domain_name" {
  type    = "string"
  default = "dev"
}

variable "noticast_shell_server_deploy_key" {
  type    = "string"
  default = "Ryan-Yubikey"
}

variable "noticast_web_server_count" {
  type    = "string"
  default = "3"
}

variable "subnet_azs" {
  type    = "list"
  default = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1e", "us-east-1f"]
}

variable "vpc_cidr" {
  type    = "string"
  default = "172.31.0.0/16"
}

variable "private_subnet_cidr" {
  type    = "string"
  default = "172.31.96.0/20"
}

variable "private_subnet_ips" {
  type    = "list"
  default = ["172.31.47.124"]
}

variable "sentry_dsn_noticast_web" {
  type    = "string"
  default = "https://e9a4a3c273a6470c8ded06978dae8112:13a7e4334a0e413d91d7d7958300d68f@sentry.io/1261427"
}

variable "sentry_dsn_lambda" {
  type    = "string"
  default = "https://c18c105462e746ecaf312df90b860703:fd8fdd4e6cc54380ad96ef3231f1de34@sentry.io/1267850"
}
