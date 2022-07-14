provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region = var.region
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc-cidr
  enable_dns_hostnames = true
}

resource "aws_subnet" "subnet-a" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.subnet-cidr-a
  availability_zone = "${var.region}a"
}

resource "aws_subnet" "subnet-b" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.subnet-cidr-b
  availability_zone = "${var.region}b"
}

resource "aws_subnet" "subnet-c" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.subnet-cidr-c
  availability_zone = "${var.region}c"
}

resource "aws_subnet" "subnet-private" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.subnet-cidr-private
  availability_zone = "${var.region}c"
}

resource "aws_eip" "ip" {
  vpc      = true
}

resource "aws_nat_gateway" "nat-gateway" {
  allocation_id = "${aws_eip.ip.id}"
  subnet_id     = "${aws_subnet.subnet-a.id}"
}

resource "aws_route_table" "subnet-private-route-table" {
  vpc_id = "${aws_vpc.vpc.id}"


  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.nat-gateway.id}"
  }
}

resource "aws_route_table_association" "subnet-private-route-table-association" {
  subnet_id      = aws_subnet.subnet-private.id
  route_table_id = aws_route_table.subnet-private-route-table.id
}

resource "aws_route_table" "subnet-route-table" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route" "subnet-route" {
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
  route_table_id         = aws_route_table.subnet-route-table.id
}

resource "aws_route_table_association" "subnet-a-route-table-association" {
  subnet_id      = aws_subnet.subnet-a.id
  route_table_id = aws_route_table.subnet-route-table.id
}

resource "aws_route_table_association" "subnet-b-route-table-association" {
  subnet_id      = aws_subnet.subnet-b.id
  route_table_id = aws_route_table.subnet-route-table.id
}

resource "aws_route_table_association" "subnet-c-route-table-association" {
  subnet_id      = aws_subnet.subnet-c.id
  route_table_id = aws_route_table.subnet-route-table.id
}

resource "aws_instance" "instance" {
  ami                         = data.aws_ami.amazon-2.id
  instance_type               = "t2.small"
  vpc_security_group_ids      = [ aws_security_group.security-group.id ]
  subnet_id                   = aws_subnet.subnet-a.id
  associate_public_ip_address = true
  user_data                   = <<EOF
#!/bin/sh
yum install -y nginx
service nginx start
EOF
}

resource "aws_instance" "instance2" {
  ami                         = data.aws_ami.amazon-2.id
  instance_type               = "t2.small"
  vpc_security_group_ids      = [ aws_security_group.security-group.id ]
  subnet_id                   = aws_subnet.subnet-c.id
  associate_public_ip_address = true
  user_data                   = <<EOF
#!/bin/sh
yum install -y nginx
service nginx start
EOF
}

resource "aws_elb" "server_lb" {
  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  health_check {
    healthy_threshold = 5
    interval = 10
    target = "HTTP:80/"
    timeout = 5
    unhealthy_threshold = 3
  }
}

resource "aws_elb_attachment" "attach_ec2_to_elb" {
  elb = "${aws_elb.server_lb.id}"
  #instance = "${format("$${aws_instance.web_servers.%d.id}",count.index)}"
  instance = "${aws_instance.instance.id}"
  depends_on = ["aws_instance.instance"]
}
resource "aws_elb_attachment" "attach_ec2_to_elb_second_instance" {
  elb = "${aws_elb.server_lb.id}"
  instance = "${aws_instance.instance2.id}"
  depends_on = ["aws_instance.instance2"]
}


output "aws_lb" {
  value = "${aws_elb.server_lb.dns_name}"
}


resource "aws_security_group" "security-group" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
    from_port   = "443"
    to_port     = "443"
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}
data "aws_ami" "amazon-2" {
  most_recent = true

  filter {
    name = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
  owners = ["amazon"]
}

output "nginx_domain" {
  value = aws_instance.instance.public_dns
}
