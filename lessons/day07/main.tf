resource "aws_instance" "web_server" {
  ami           = "ami-0e8459476fed2e23b"
  instance_type = "t2.micro"
  count = var.instance_count    # number
  monitoring = true    # boolean
  tags = var.tags    # map of values

  # accessing the value of the object
  region = var.config.region

}

resource "aws_security_group" "allow_tls" {
  name = "allow_tls"
  description = "Allow inbound traffic on port 443"
  tags = {
    Name = "allow_tls"
  }  
}

resource "aws_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.allow_tls.id

  # use from the tuple
  from_port = var.ingress_values[0]
  to_port = var.ingress_values[2]
  protocol = var.ingress_values[1]


  cidr_ipv4 = var.cidr_block[0]  # accessing elements in the list
}
