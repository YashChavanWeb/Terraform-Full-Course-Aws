variable "bucket_name" {
  description = "Name of the S3 bucket"
  default     = "test-remote-backend"
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"
}

variable "environment" {
  description = "The environment tag for resources (e.g., dev, staging, prod)"
  default     = "dev"
}

