variable "environment" {
    type = string
    default = "dev"
}

variable "ingress_rules" {
   type = list(object({
    from_port = number
    to_port = number
    protocol = string
    cidr_blocks = list(string)
   }))
   default = [
    {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port = 443
      to_port = 443
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
   ]
}