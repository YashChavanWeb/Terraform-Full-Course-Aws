# Terraform Provisioners

## What are Provisioners?

A Provisioner is something that performs a task—for example, running a file, executing a command, or performing some operation. Provisioners are used to execute scripts on a remote machine.

## Types of Provisioners

1. **local-exec**

   - Used when we want to execute commands locally.
   - It runs on the local machine where your Terraform host resides.

2. **remote-exec**

   - Executes commands remotely on a target machine.
   - This requires an SSH connection—for example, installing nginx on a remote machine.

3. **file**
   - Used to copy a file from one machine to another.
   - This also requires an SSH connection and a Key Pair.

## Practical Example

The first step is to create a Key Pair for connecting to instances remotely.  
To create a Key Pair, we need to have AWS CLI installed and `aws configure` already set up.

```
# Verify AWS credentials are set
aws sts get-caller-identity
```

The command for creating a Key Pair (choose the same folder where the .pem file is created) using AWS CLI:

```
aws ec2 create-key-pair --key-name terraform-demo-key \
  --query 'KeyMaterial' --output text > terraform-demo-key.pem
chmod 400 terraform-demo-key.pem
```

We will pass this Key Pair from the command line when we run `terraform apply` later.

Now, for testing the provisioners, we need to complete the following tasks:

1. Create an EC2 instance.  
   To create this instance, we also need:
   - A Data Source for the AMI
   - A Security Group to configure incoming and outgoing traffic

### Creating the Data Source

We create a data source for the AMI configuration of the EC2 instance, adding the necessary filters:

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu official)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
```

### Security Group

This is used to manage the ingress (incoming) and egress (outgoing) traffic:

```hcl
resource "aws_security_group" "ssh" {
  name        = "tf-prov-demo-ssh"
  description = "Allow SSH inbound"

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
}
```

### EC2 Instance

In the EC2 instance, we need to specify the Key Pair, but we are passing it from the terminal when running `terraform apply`. Therefore, we create a variable for it.

```hcl
resource "aws_instance" "demo" {
  ami                    = data.aws_ami.ubuntu.id  # taken from the data source
  instance_type          = var.instance_type
  key_name               = var.key_name    # here we use the Key Pair we created
  vpc_security_group_ids = [aws_security_group.ssh.id]  # taken from the security group we created

  tags = {
    Name = "terraform-provisioner-demo"
  }
}
```

Variable definition (no default value, so it is required and must be provided during apply):

```hcl
variable "key_name" {
  description = "Name of an existing EC2 key pair (must already exist in the chosen region)"
  type        = string
}
```

Now, to connect to the EC2 instance via SSH, we need to add a `connection` object:

```hcl
resource "aws_instance" "demo" {
  ami                    = data.aws_ami.ubuntu.id
  ...

  connection {
    type        = "ssh"    # how we want to connect to the instance/server
    user        = var.ssh_user    # the username - it can be ubuntu
    private_key = file(var.private_key_path)   # the private key we created
    host        = self.public_ip
  }
}
```

The connection includes an important property called `private_key`.  
This key cannot be passed directly via the terminal or in locals/variables. Instead, we must provide the file itself. For this, we create a variable for the file path and then, when running `terraform plan`, we can also pass the `private_key` path.

```hcl
variable "private_key_path" {
  description = "Path to the private key file for SSH (used by remote provisioners)"
  type        = string
}
```

We also used the `self` keyword.  
If we want to access the public IP of the instance, we can use `self`, which refers to the current resource being created.

### Execution

Now we can run `terraform init`.  
To apply, we must pass the Key Pair variables during runtime using `-var`:

```
terraform apply -var "key_name=terraform-demo-key" -var "private_key_path=./terraform-demo-key.pem"
```

Up to this point, the basic infrastructure is created, but now we need to add provisioners.

### Provisioners

We add provisioners inside the resource we are creating, in this case, the `aws_instance`:

```hcl
resource "aws_instance" "demo" {
  ami                    = data.aws_ami.ubuntu.id
  ...

  connection {
    type        = "ssh"
    ...
  }

  provisioner "local-exec" {
    command = "echo 'Local-exec: created instance ${self.id} with IP ${self.public_ip}'"
  }
}
```

This command will run on the EC2 instance, and we can use `self.id` and `self.public_ip` for reference.

### Testing the Provisioners

- When testing, we cannot just run `terraform apply` because the provisioner only executes and does not change any resource.
- Since there is no change in the resources, it will have no effect.  
  Therefore, we must use:

```
terraform taint aws_instance.demo
```

This marks the resource as “tainted,” so Terraform will recreate it. Then, we run the `apply` command again with the environment variables.

## Remote Exec

We can add a `remote-exec` provisioner inside the `aws_instance` resource:

```hcl
resource "aws_instance" "demo" {
  ami                    = data.aws_ami.ubuntu.id
  ...

  connection {
    type        = "ssh"
    ...
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "echo 'Hello from remote-exec' | sudo tee /tmp/remote_exec.txt",
    ]
  }
}
```

This will update the applications and create a file in the `/tmp` directory with the given text.  
To run it, we can taint the instance first and then apply as before:

```
terraform taint aws_instance.demo
terraform apply -var "key_name=terraform-demo-key" -var "private_key_path=./terraform-demo-key.pem"
```

## File Provisioner

Copying a file from the local machine to the remote machine:

```hcl
provisioner "file" {
  source      = "${path.module}/scripts/welcome.sh"
  destination = "/tmp/welcome.sh"
}
```

Again, taint and apply.  
After adding the file to the remote server, we can also execute it using `remote-exec`:

```hcl
provisioner "remote-exec" {
  inline = [
    "sudo chmod +x /tmp/welcome.sh",
    "sudo /tmp/welcome.sh"
  ]
}
```
