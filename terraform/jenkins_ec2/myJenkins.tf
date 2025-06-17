terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.5"
    }
  }
  required_version = ">= 1.8"

  backend "s3" {
    bucket = "terraform-state-angela"
    key    = "jenkins/tf-test-state.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "random_pet" "sg_name" {}

resource "aws_security_group" "web_sg" {
  name = "${random_pet.sg_name.id}-jenkins-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins-sg"
  }
}

resource "aws_instance" "jenkins" {
  ami                         = "ami-0c7217cdde317cfec" # Ubuntu 22.04 x86_64 us-east-1
  instance_type               = "c7a.medium"
  key_name                    = "DevopsCourseKeys"
  vpc_security_group_ids      = [aws_security_group.web_sg.id]

  root_block_device {
    volume_size = 25
    volume_type = "gp3"
  }

  tags = {
    Name = "jenkins-server"
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io
              systemctl start docker
              systemctl enable docker
              docker run -d \
                -p 8080:8080 \
                --name jenkins \
                -v jenkins_home:/var/jenkins_home \
                jenkins/jenkins:lts
              EOF
}
