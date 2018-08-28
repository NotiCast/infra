# vim:set et sw=2 ts=2 foldmethod=marker:

variable "stage" {
  type = "string"
}

variable "domain_name" {
  type = "string"
}

variable "route53_zone_id" {
  type = "string"
}

variable "filename" {
  type = "string"
}

variable "function_name" {
  type = "string"
}

variable "subnet_ids" {
  type = "list"
}

variable "security_group_ids" {
  type = "list"
}

variable "db_endpoint" {
  type = "string"
}

variable "db_name" {
  type = "string"
}

variable "db_auth" {
  type = "string"
}

variable "bucket_name" {
  type = "string"
}

variable "email_name" {
  type = "string"
}

variable "sentry_dsn" {
  type = "string"
}
