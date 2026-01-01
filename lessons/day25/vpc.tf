variable "vpc_id" {}

data "aws_vpc" "selected" {
  id = var.vpc_id
  default = true
}