terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Provider alias for ACM certificate (CloudFront requires certificates in us-east-1)
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}
