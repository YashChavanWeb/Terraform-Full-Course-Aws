terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Create a VPC
resource "aws_vpc" "example" {      ## Internal reference of terraform
  cidr_block = "10.0.0.0/16"
}

resource "aws_ec2_instance" "name" {
    vpc_id = aws_vpc.example.id    # The internal reference is used here
}