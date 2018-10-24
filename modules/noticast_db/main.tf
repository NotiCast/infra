# Relational Database System [MySQL] {{{

resource "random_string" "database_password" {
  length  = 24
  special = false
}

resource "aws_db_instance" "main" {
  name                = "${var.db_name}"
  allocated_storage   = 10
  engine              = "mysql"
  engine_version      = "5.7"
  instance_class      = "db.t2.micro"
  username            = "${var.db_user}"
  password            = "${random_string.database_password.result}"
  skip_final_snapshot = true
}

# }}}

