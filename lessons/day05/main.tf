# Configure the AWS Provider
terraform {

  # backend configuration
  backend "s3" {
    bucket         = "awsbucket.yashchavan"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile  = "true"
  }

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  # Configuration options
    region = "us-east-1"
}

variable "environment" {
    default = "dev"
    type = string
}

locals {
  bucket_name="${var.environment}.yashchavan-bucket"
  vpc_name="${var.environment}.yashchavan-vpc"
}


resource "aws_instance" "ec2" {
    ami = "ami-0c55b159cbfafe1f0"
    instance_type = "t2.micro"
    tags = {
        Name = "${var.environment}-ec2"
        Environment = var.environment
    }
}

resource "aws_s3_bucket" "s3" {
    bucket = local.bucket_name
    tags = {
        Name = "my-s3"
        Environment = var.environment
    }
}

resource "aws_vpc" "vpc" {
    cidr_block = ["10.0.0.0/16"]
    tags = {
        Name = "my-vpc"
        Environment = var.environment
    }
}

output "vpc_id" {
    value = aws_vpc.sample.id
}

output "ec2_id" {
    value = aws_instance.example.id
}