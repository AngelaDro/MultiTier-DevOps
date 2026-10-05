variable "vpc_id" {
  description = "ID of the VPC (default VPC or your own)"
  type        = string
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate for the HTTPS listener"
  type        = string
}

variable "admin_cidr" {
  description = "Your public IP in CIDR form, e.g. 203.0.113.10/32 (SSH + RabbitMQ UI)"
  type        = string
}

variable "key_name" {
  description = "Name of the EC2 key pair"
  type        = string
  default     = "DevopsCourseKeys"
}

variable "ami_id" {
  description = "Ubuntu AMI for us-east-1"
  type        = string
  default     = "ami-0f9de6e2d2f067fca"
}
