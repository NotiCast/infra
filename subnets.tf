resource "aws_default_vpc" "main" {}
resource "aws_default_subnet" "main" {
  count = "${length(var.subnet_azs)}"
  availability_zone = "${var.subnet_azs[count.index]}"
}

resource "aws_default_security_group" "main" {
  vpc_id = "${aws_default_vpc.main.id}"

  ingress {
    protocol = -1
    self = true
    from_port = 0
    to_port = 0
  }

  ingress {
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 80
    to_port = 80
  }

  ingress {
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 443
    to_port = 443
  }

  ingress {
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 22
    to_port = 22
  }

  egress {
    protocol = -1
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    to_port = 0
  }
}

resource "aws_subnet" "private" {
  vpc_id = "${aws_default_vpc.main.id}"
  cidr_block = "${var.private_subnet_cidr}"
}

resource "aws_network_interface" "gateway" {
  description = "Interface for NAT Gateway nat-0a511e75864098026"
  subnet_id = "${aws_default_subnet.main.1.id}"
  private_ips = "${var.private_subnet_ips}"
  source_dest_check = false
  # security_groups = ["${aws_default_security_group.main.id}"]
}

resource "aws_eip" "private-nat" {
  vpc = true
  network_interface = "${aws_network_interface.gateway.id}"
}

resource "aws_nat_gateway" "private-gateway" {
  allocation_id = "${aws_eip.private-nat.id}"
  subnet_id = "${aws_default_subnet.main.1.id}"
}

resource "aws_route_table" "private" {
  vpc_id = "${aws_default_vpc.main.id}"
}

resource "aws_route" "private-default-route" {
  route_table_id = "${aws_route_table.private.id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = "${aws_nat_gateway.private-gateway.id}"

  depends_on = ["aws_route_table.private"]
}

resource "aws_route_table_association" "private" {
  subnet_id = "${aws_subnet.private.id}"
  route_table_id = "${aws_route_table.private.id}"
}
