output "db_uri" {
  value = "mysql+pymysql://${aws_db_instance.main.username}:${aws_db_instance.main.password}@${aws_db_instance.main.endpoint}/${aws_db_instance.main.name}"
}

output "db_username" {
  value = "${aws_db_instance.main.username}"
}

output "db_password" {
  value = "${aws_db_instance.main.password}"
}

output "db_endpoint" {
  value = "${aws_db_instance.main.endpoint}"
}

output "db_name" {
  value = "${aws_db_instance.main.name}"
}
