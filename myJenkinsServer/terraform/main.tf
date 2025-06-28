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
    local = {
      source  = "hashicorp/local"
      version = "~>2.0"
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

resource "random_pet" "sg" {}

# --- IAM Role for EC2 with ECR access ---
resource "aws_iam_role" "jenkins_instance_role" {
  name = "JenkinsEC2Role" # имя роли соответствует шаблону Jenkins* из твоей IAM политики

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.jenkins_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

resource "aws_iam_instance_profile" "jenkins_profile" {
  name = "JenkinsInstanceProfile"
  role = aws_iam_role.jenkins_instance_role.name
}

# --- Security Group ---
resource "aws_security_group" "jenkins_sg" {
  name = "${random_pet.sg.id}-sg"

  ingress {
    from_port   = 22
    to_port     = 9001
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
}

# --- EC2 Instance ---
resource "aws_instance" "jenkins_instance" {
  ami                    = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS
  instance_type          = "c7a.medium"
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  key_name               = "jenkins-ansible"
  iam_instance_profile   = aws_iam_instance_profile.jenkins_profile.name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "MyJenkinsServer"
  }
}

# --- Generate Ansible inventory ---
resource "local_file" "ansible_hosts" {
  content = <<-EOT
    [jenkins]
    ${aws_instance.jenkins_instance.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/jenkins-ansible.pem
  EOT
  filename = "../ansible/hosts"
}

# --- Outputs ---
output "jenkins_server_public_ip" {
  description = "Public IP address of the Jenkins EC2 instance"
  value       = aws_instance.jenkins_instance.public_ip
}
