# Project - Two Tier Web Application using Flask and MySQL

## 1. Secret Module

First is creating a secret module, which will be having the secret variable values.
Eg: DB password will be automatically generated and we don't have to hardcode it.

### First is the random password

So as we are creating the MYSQL RDS instance, we need to create a password for it which can be done by this:

```hcl
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}
```

### Second is the random string

So anytime we create a new resource, in order for it to be unique, it should have a unique name, for that we can use the random id as the suffix:

```hcl
resource "random_id" "suffix" {
  byte_length = 4
}
```

### AWS Secret Manager

We are going to protect all the secrets using the AWS Secret Manager.
So for doing that we will simply first create its resource:

```hcl
resource "aws_secretsmanager_secret" "db_password" {
  name        = "${var.project_name}-${var.environment}-db-password-${random_id.suffix.hex}"
  description = "Database password for ${var.project_name}"

  tags = {
    Name        = "${var.project_name}-db-password"
    Environment = var.environment
  }
}
```

After this we can version the resource to create the password for the database.
So we need to give the secret string - for how the password will be created.
This will be created as a JSON file and then stored in the resource of secret manager:

```hcl
resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id  ## referring the manager that we just created above
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    engine   = "mysql"
    host     = "" # Will be populated by application or looked up
  })
}
```

## 2. VPC

So we are going to create the VPC in the similar fashion.
Just for the RDS, we need to have at least 2 subnets in different availability zones, so that we can provision them.
So the steps for the VPC would be:

- Creating a VPC -> aws_vpc and CIDR block
- Then the next is having a public subnet for everyone to access the internet
- Now for the RDS, we create two private subnets in different AZs
- Then we require the internet gateway for access to the internet with the VPC id
- Then a public route table
- And finally the association of the route table with the public subnet id

Example of creating the two private subnets for RDS:

```hcl
# Private Subnets for RDS (requires at least 2 AZs)
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[0]
  availability_zone = "${var.aws_region}a"

  tags = {
    Name        = "${var.project_name}-private-subnet-1"
    Environment = var.environment
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[1]
  availability_zone = "${var.aws_region}b"

  tags = {
    Name        = "${var.project_name}-private-subnet-2"
    Environment = var.environment
  }
}
```

> Optional - we can also create a NAT gateway and its route table association.  
> A NAT gateway allows instances in a private subnet to access the internet while keeping them secure from inbound traffic. It simplifies and scales outbound internet access for cloud networks.

## 3. Security Groups

Now we also have a separate module for security group:

1. **Web security group** - it will have the VPC id and we will enable:

   - Port 80 to HTTP from anywhere
   - Port 22 (SSH) from anywhere / only your IP

2. **Database security group** - we are allowing:
   - Ingress only on the web security group created on port 3306 (MYSQL PORT)
   - Egress to allow all outbound access with protocol -1

> **Note**: Implement a NAT Gateway here as well if required for more security.

## 4. RDS

Now finally we create the RDS instance:

```hcl
# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Environment = var.environment
  }
}

# RDS MySQL Instance
resource "aws_db_instance" "main" {
  identifier             = "${var.project_name}-db"
  allocated_storage      = var.allocated_storage
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = var.engine_version
  instance_class         = var.instance_class
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  parameter_group_name   = "default.mysql8.0"
  skip_final_snapshot    = true
  vpc_security_group_ids = [var.db_security_group_id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  publicly_accessible    = false

  tags = {
    Name        = "${var.project_name}-rds"
    Environment = var.environment
  }
}
```

The way the root modules get the value from the custom modules is from the output variables of the custom modules.

## 5. EC2

Creating the EC2 resource - we are getting the other details from the custom modules, once the resources are created from their output variables:

```hcl
# EC2 Instance
resource "aws_instance" "web" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.web_security_group_id]
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/templates/user_data.sh", {
    db_host     = var.db_host
    db_username = var.db_username
    db_password = var.db_password
    db_name     = var.db_name
  })

  tags = {
    Name        = "${var.project_name}-web-server"
    Environment = var.environment
  }
}
```

After running the 3 terraform commands:

```bash
terraform init
terraform plan -auto-approve
terraform apply -auto-approve
```

We can access the application using the web server public DNS variable URL.
