# Terraform AWS Provider

The **AWS Provider** is a plugin that allows Terraform to interact with AWS services.

## Simple Code Snippet

```tf
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 6.7.0"    # Version of the provider
    }
    random {
        source = "hashicorp/random"
        version = "3.1"
    }
    required_version = ">= 1.0"  # Version of terraform
  }
}

provider "aws" {
  region = "us-east-1"
}
```

## Why Versioning Matters

* The **Terraform binary** is maintained by HashiCorp.
* The **providers** (like AWS) are maintained by the **AWS community**.

## Version Constraints

* `=` → Match the **exact version**; will not upgrade.
* `!=` → **Exclude** that version.
* `~>` → Match the version written and the next **minor** version (e.g., `6.7.0` → `6.7.9`, but will not exceed the middle part).
* `>` → Greater than the version written.
* `<` → Less than the version written.
* `>=` → Greater than or equal to the version written.
* `<=` → Less than or equal to the version written.

## Getting Started

* Write a simple `.tf` configuration:

```tf
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
resource "aws_vpc" "example" {      # Internal reference of terraform
  cidr_block = "10.0.0.0/16"
}

resource "aws_ec2_instance" "name" {
    vpc_id = aws_vpc.example.id    # The internal reference is used here
}
```

* To initialize Terraform, run:

```bash
terraform init
```

This will create a `.terraform` folder and a `lock.hcl` file on Windows.

* Before you can plan the deployment, you need to configure AWS credentials by running:

```bash
aws configure
```

Then, enter the **access key** and **secret key** from your IAM user to authenticate.

* After successful authentication, you can plan the deployment with:

```bash
terraform plan
```
