variable "server_count" {
  type = "string"
}

variable "security_group_ids" {
  type = "list"
}

variable "elb_availability_zones" {
  type = "list"
}

variable "ec2_key_name" {
  type = "string" # deployer-key
}

variable "domain_name" {
  type = "string"
}

variable "route53_zone_id" {
  type = "string"
}

variable "dummy_depends_on" {
  type = "list"
}

variable "aws_region" {
  type = "string"
}

variable "aws_user" {
  type = "string"
}

variable "stage_name" {
  type = "string"
}
