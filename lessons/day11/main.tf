locals {
  # formatted_project_name = tolower(var.project_name)
  formatted_project_name = tolower(replace(var.project_name, " ", "_"))
  
  # validations for the bucketname
  formatted_bucket_name = replace(
    replace(substr(tolower(var.bucket_name), 0, 63), " ", "-"),
    "!",
    ""
  )

  port_list = split(",", var.allowed_ports)

  sg_rules = [for port in local.port_list : {
    name="port-${port}"
    port = port
  }]

  instance_size = lookup(var.instance_sizes, var.environment, "t2.micro")
}

resource "aws_s3_bucket" "name" {
  bucket = local.formatted_bucket_name


  tags = merge(var.default_tags, var.environment_tags)
}