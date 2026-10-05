terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }

  required_version = ">= 1.8"

  backend "s3" {
    bucket = "terraform-state-angela"
    key    = "multitier/tf-test-state.tfstate"
    region = "us-east-1"
    encrypt = true
    # State locking: create a DynamoDB table (hash key "LockID") and uncomment:
    # dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = "us-east-1"
}


data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}

# --- Security groups -------------------------------------------------------
# ALB: the only component that is open to the whole internet (HTTP/HTTPS).
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Public entry point: HTTP/HTTPS"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    description = "HTTP (redirected to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Application servers: SSH and the RabbitMQ web UI only from my own IP,
# backend ports only between the servers themselves, Tomcat only via ALB.
resource "aws_security_group" "main_sg" {
  name        = "main-service-sg"
  description = "Application servers"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    description = "SSH from admin IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "RabbitMQ web UI from admin IP only"
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description     = "Tomcat from the load balancer"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Servers talk to each other over PRIVATE IPs (see output private_ips).
  dynamic "ingress" {
    for_each = {
      "Tomcat (from Nginx)" = 8080
      "MySQL"               = 3306
      "Memcached"           = 11211
      "RabbitMQ"            = 5672
    }
    content {
      description = "${ingress.key} between servers"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      self        = true
    }
  }

  # Optional: Nginx reverse proxy reachable directly on port 80.
  ingress {
    description = "HTTP to Nginx"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "mysql" {
  ami                         = var.ami_id
  instance_type               = "t3.micro"
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.main_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  tags = {
    Name = "mysql"
  }
}

resource "aws_instance" "memcached" {
  ami                         = var.ami_id
  instance_type               = "t2.micro"
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.main_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  tags = {
    Name = "memcached"
  }
}

resource "aws_instance" "rabbitmq" {
  ami                         = var.ami_id
  instance_type               = "t3.micro"
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.main_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }  

  tags = {
    Name = "rabbitmq"
  }
}

resource "aws_instance" "tomcat" {
  ami                         = var.ami_id
  instance_type               = "t3.micro"
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.main_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  tags = {
    Name = "tomcat"
  }
}

resource "aws_instance" "nginx" {
  ami                         = var.ami_id
  instance_type               = "t2.micro"
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.main_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  tags = {
    Name = "nginx"
  }
}

resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.selected.ids
  enable_deletion_protection = false
}

resource "aws_lb_target_group" "tomcat_tg" {
  name     = "tomcat-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.selected.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "tomcat_attach" {
  target_group_arn = aws_lb_target_group.tomcat_tg.arn
  target_id        = aws_instance.tomcat.id
  port             = 8080
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tomcat_tg.arn
  }
}

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "local_file" "ansible_hosts" {
  content = <<-EOT
    [mysql]
    ${aws_instance.mysql.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/${var.key_name}.pem

    [memcached]
    ${aws_instance.memcached.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/${var.key_name}.pem

    [rabbitmq]
    ${aws_instance.rabbitmq.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/${var.key_name}.pem

    [tomcat]
    ${aws_instance.tomcat.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/${var.key_name}.pem

    [nginx]
    ${aws_instance.nginx.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/${var.key_name}.pem
  EOT
  filename = "../ansible/hosts"
}

output "server_public_ips" {
  description = "Public IP addresses of all EC2 instances"
  value = {
    mysql     = aws_instance.mysql.public_ip
    memcached = aws_instance.memcached.public_ip
    rabbitmq  = aws_instance.rabbitmq.public_ip
    tomcat    = aws_instance.tomcat.public_ip
    nginx     = aws_instance.nginx.public_ip
  }
}

output "private_ips" {
  description = "Private IPs - use these in the application config so SG rules apply"
  value = {
    mysql     = aws_instance.mysql.private_ip
    memcached = aws_instance.memcached.private_ip
    rabbitmq  = aws_instance.rabbitmq.private_ip
    tomcat    = aws_instance.tomcat.private_ip
    nginx     = aws_instance.nginx.private_ip
  }
}

output "alb_dns_name" {
  value = aws_lb.app_lb.dns_name
}
