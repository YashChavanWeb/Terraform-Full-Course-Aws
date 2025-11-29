# Generate random string for unique bucket name
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 Bucket resource
resource "aws_s3_bucket" "test_backend" {
  bucket = local.s3_bucket_name

  tags = {
    Name        = "Test Backend Bucket"
    Environment = var.environment
  }
}

# VPC resource
resource "aws_vpc" "main_vpc" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Name        = local.vpc_name
    Environment = var.environment
  }
}

# EC2 instance resource
resource "aws_instance" "test_instance" {
  ami           = "ami-0c55b159cbfafe1f0" 
  instance_type = var.ec2_instance_type
  subnet_id     = aws_subnet.main_subnet.id

  tags = {
    Name        = local.ec2_instance_name
    Environment = var.environment
  }
}

# Subnet resource (for EC2 instance)
resource "aws_subnet" "main_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1" 
  map_public_ip_on_launch = true

  tags = {
    Name        = "Main Subnet"
    Environment = var.environment
  }
}
