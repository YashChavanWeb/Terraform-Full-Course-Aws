variable "project_name" {
  default     = "Project ALPHA Resource"
}

variable "default_tags" {
  default = {
    company = "Yashchavan"
    managed_by = "Terraform"
  }
}

variable "environment_tags" {
  default = {
    environment = "dev"
    cost_center = "1001"
  }
}

variable "bucket_name" {
  # make the name complex - not fit in aws standards
  default = "Yash chavan is the bucket name!!!!"
}

variable "allowed_ports" {
  default = "22,80,443"
}

variable "instance_sizes" {
  default = {
    dev = "t2.micro"
    staging = "t2.small"
    prod = "t2.medium"
  }
}

variable "environment" {
  default = "dev"
}