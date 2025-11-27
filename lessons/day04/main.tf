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
    region = "ca-central-1"
}


# Simple test resource to verify remote backend
resource "aws_s3_bucket" "test_backend" {
  bucket = "test-remote-backend-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "Test Backend Bucket"
    Environment = "dev"
  }
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}
