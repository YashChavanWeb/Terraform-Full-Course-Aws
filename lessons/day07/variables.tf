variable "instance_count" {
  type = number
  description = "Number of EC2 instances to create"
}

variable "region" {
  type = string
  description = "AWS region to create the EC2 instances"
}

variable "cidr_block" {
  description = "List of CIDR blocks for the security group"
  type = list(string)   # list of strings (datatype cannot change)
  default = [ "0.0.0.0/0", "10.0.0.0/24", "172.16.0.0/16", "192.168.0.0/16" ]
}

variable "allowed_vm_types" {
  description = "List of allowed VM types"
  type = list(string)
  default = [ "t2.micro", "t2.small", "t2.medium" ]
}

variable "allowed_region" {
  description = "List of allowed regions"
  type = set(string)
  default = [ "us-east-1", "us-east-2", "us-west-1", "us-west-2" ]
}

variable "tags" {
  description = "Tags to apply to the EC2 instances"
  type = map(string)
  default = {
    Name = var.Name
    Environment = var.Environment
    Project = var.Project
  }
}

variable "ingress_values" {
  description = "Ingress values for the security group"
  type = tuple([number, string, number])
  default = [ 443, "tcp", 443 ]
}

variable "config" {
  description = "Configuration for the EC2 instances"
  type = object({
    instance_type = string
    region = string
    cidr_block = list(string)
    allowed_vm_types = list(string)
    allowed_region = set(string)
    tags = map(string)
    ingress_values = tuple([number, string, number])
  })
}