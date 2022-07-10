terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = "true"
  enable_dns_support = "true"
  tags = {
    Name = "VpcTest"
  }
}
resource "aws_subnet" "main1" {
  vpc_id = aws_vpc.main.id
  availability_zone = "us-east-1a"
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "PublicSubnet-1"
  }
}
resource "aws_subnet" "main2" {
  vpc_id = aws_vpc.main.id
  availability_zone = "us-east-1b"
  cidr_block = "10.0.2.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "PublicSubnet-2"
  }
}
resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.main.id
  tags = {
      Name = "ANDIGW"
  }
}
resource "aws_route_table" "MainRouteTable" {
  vpc_id = aws_vpc.main.id
route {
  cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.IGW.id
}
  tags = {
    Name = "PublicRouteTable"
  }
}
resource "aws_route_table_association" "public-subnet-1-route-table-association" {
subnet_id           = aws_subnet.main1.id
route_table_id      = aws_route_table.MainRouteTable.id
}
resource "aws_route_table_association" "public-subnet-2-route-table-association" {
subnet_id           = aws_subnet.main2.id
route_table_id      = aws_route_table.MainRouteTable.id
}
resource "aws_security_group" "WebSecurityGroup" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "SecurityGroup"
  }
  ingress {
    description = " Allow port 80"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = " Allow port 443"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_instance" "web-server1" {
  ami           = "ami-0c293f3f676ec4f90"
  instance_type = "t2.micro"
  security_groups             = ["${aws_security_group.WebSecurityGroup.id}"]
  subnet_id                   = "${aws_subnet.main1.id}"
  user_data = <<-EOF
          #!/bin/bash
          sudo su
          yum update -y
          yum install httpd -y
          systemctl start httpd
          systemctl enable httpd
           echo "Hello World from $(hostname -f)" > /var/www/html/index.html
    EOF
  
  tags = {
    Name = "WebServer1"
  }
  
}
resource "aws_instance" "web-server2" {
  ami           = "ami-0c293f3f676ec4f90"
  instance_type = "t2.micro"
  security_groups             = ["${aws_security_group.WebSecurityGroup.id}"]
  subnet_id                   = "${aws_subnet.main2.id}"
  user_data = <<-EOF
          #!/bin/bash
          sudo su
          yum update -y
          yum install httpd -y
          systemctl start httpd
          systemctl enable httpd
           echo "Hello World from $(hostname -f)" > /var/www/html/index.html
    EOF

  tags = {
    Name = "WebServer2"
  }
}

resource "aws_alb_target_group" "target-group" {
  health_check {
    interval        = 10
    path            = "/"
    protocol = "HTTP"
    timeout = 5
    healthy_threshold = 5
    unhealthy_threshold = 2
  

}

  port = 80
  protocol = "HTTP"
  target_type = "instance"
  vpc_id = aws_vpc.main.id 
    
  }

resource "aws_lb" "application-lb" {
    name = "and-alb"
    internal = false
    ip_address_type = "ipv4"
    load_balancer_type = "application"
    security_groups = [aws_security_group.WebSecurityGroup.id]
    subnets = [aws_subnet.main1.id, aws_subnet.main2.id]

    tags = {
      Name = "and-alb"
    }
  
}

resource "aws_lb_listener" "alb-listener" {
  load_balancer_arn = aws_lb.application-lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.target-group.arn
    type = "forward"

    
  }
}



resource "aws_lb_target_group_attachment" "web1" {
  
  target_group_arn = aws_alb_target_group.target-group.arn
  target_id = aws_instance.web-server1.id
}

resource "aws_lb_target_group_attachment" "web2" {
  
  target_group_arn = aws_alb_target_group.target-group.arn
  target_id = aws_instance.web-server2.id
}