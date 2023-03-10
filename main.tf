resource "aws_vpc" "example_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "example-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id = aws_vpc.example_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id = aws_vpc.example_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = false
  tags = {
    Name = "private-subnet"
  }
}

resource "aws_internet_gateway" "example_igw" {
  vpc_id = aws_vpc.example_vpc.id
  tags = {
    Name = "example-igw"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.example_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.example_igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_eip" "example_eip" {
  vpc = true
}

resource "aws_nat_gateway" "example_nat_gateway" {
  allocation_id = aws_eip.example_eip.id
  subnet_id = aws_subnet.public_subnet.id
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.example_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.example_nat_gateway.id
  }

  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route_table_association" "private_subnet_association" {
  subnet_id = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_security_group" "elb_security_group" {
  name = "elb-security-group"
  description = "Allow traffic to the ELB"
  vpc_id = aws_vpc.example_vpc.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elb" "example_elb" {
  name = "example-elb"
  subnets = [aws_subnet.public_subnet.id]
  security_groups = [aws_security_group.elb_security_group.id]

  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  health_check {
    target = "HTTP:80/"
    interval = 30
    timeout = 5
  }
}

resource "aws_security_group" "web_security_group" {
  name = "web-security-group"
  description = "Allow traffic to the web server"
  vpc_id = aws_vpc.example_vpc.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    security_groups = [aws_security_group.elb_security_group.id]
  }
}

resource "aws_launch_configuration" "example_launch_config" {
  image_id = "ami-0c94855ba95c71c99"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.web_security_group.id]

  user_data = <<-EOF
              #!/bin/bash
              echo "<html><body><h1>Hello, World!</h1></body></html>" > /var/www/html/index.html
              service httpd start
              EOF
}

resource "aws_autoscaling_group" "example_autoscaling_group" {
  name = "example-autoscaling-group"
  vpc_zone_identifier = [aws_subnet.private_subnet.id]
  launch_configuration = aws_launch_configuration.example_launch_config.id
  min_size = 1
  max_size = 3
  health_check_type = "ELB"
  health_check_grace_period = 300
  load_balancers = [aws_elb.example_elb.name]
}

resource "aws_security_group" "example_security_group" {
  name = "example-security-group"
  description = "Allow traffic to the EC2 instance"
  vpc_id = aws_vpc.example_vpc.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "public_subnet_id" {
  value = aws_subnet.public_subnet.id
}

output "private_subnet_id" {
  value = aws_subnet.private_subnet.id
}

output "elb_dns_name" {
  value = aws_elb.example_elb.dns_name
}
