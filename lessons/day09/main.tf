variable "allowed_region" {
    type = set(string)
    default = ["us-east-1", "us-west-1", "us-west-2"]
}

variable "tags" {
    type = map(string)
    default = {
        Environment = "Production"
        Project = "Example"
    }
}

resource aws_instance example {
  ami = "ami-0ff8a91507f77f867"
  instance_type = "t2.micro"
  region = tolist(var.allowed_region)[0] 
  
  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_security_group" "example_security_group" {
  name        = "example-security-group"
  description = "Allow SSH inbound traffic"
  vpc_id      = "vpc-0abcdef1234567890"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_instance" "example_instance_with_sg" {
  ami                    = "ami-0ff8a91507f77f867"
  instance_type          = "t2.micro"
  region                 = tolist(var.allowed_region)[0]
  vpc_security_group_ids = [aws_security_group.example_security_group.id]

  tags = var.tags

  lifecycle {
    replace_triggered_by = [aws_security_group.example_security_group.id]
  }
}

