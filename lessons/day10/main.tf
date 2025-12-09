resource "aws_instance" "my-instance-1" {
  ami = "ami-0c55b159cbfafe1f0"
  
    #   instance_type = "t2.micro"
    instance_type = var.environment == "dev" ? "t2.micro" : "t3.micro"

  count = 2
  tags = {
    Name = "my-instance-1"
    Env = var.environment
  }
} 

# security group rule
resource "aws_security_group" "my-sg" {
    name = "my-sg"
    description = "my-sg"

    dynamic "ingress" {
        for_each = var.ingress_rules
        content {
            from_port = ingress.value.from_port
            to_port = ingress.value.to_port
            protocol = ingress.value.protocol
            cidr_blocks = ingress.value.cidr_blocks
        }
    }
}

locals {

# Any one you can use

    # instance_ids = aws_instance.my-instance-1.*.id
    instance_ids = aws_instance.my-instance-1[*].id
}   

output "all_instance_ids" {
    value = local.instance_ids
}