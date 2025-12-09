# Terraform Data Sources

#### Scenario Example:

- **Problem**: When provisioning an EC2 instance, we typically need to specify an AMI ID manually.
- **Solution**: Using a **data source**, we can just specify the **name** of the AMI image, and Terraform will automatically fetch the correct **AMI ID**.

---

### What is a Data Source?

- **Definition**: A data source in Terraform allows you to **read** information about existing infrastructure.

- **Key Characteristics**:

  - **Doesn't Modify Resources**: Data sources **do not** create, update, or delete any resources.
  - **Reference External Resources**: They enable referencing resources that are managed elsewhere (e.g., by other teams, outside Terraform, or in different accounts).
  - **Sharing Infrastructure**: Useful for sharing infrastructure details across different teams or departments.
  - **Defined with `data` Blocks**: Unlike resources, data sources are defined with `data` blocks (e.g., `data "aws_vpc" "vpc_name"`).

---

### Enterprise Example

Let's say in your enterprise, multiple teams share the same VPC:

- **DevOps Team**
- **QA Team**

The VPC has two subnets, and each subnet contains two EC2 instances.

For provisioning these EC2 instances dynamically, we want to avoid hardcoding things like VPC ID, Subnet ID, or AMI IDs. Instead, we will use data sources to pull this information into our Terraform configuration.

### Step-by-Step Breakdown

---

#### 1. **Creating Data Source for the VPC**

```hcl
# Datasource for the VPC
data "aws_vpc" "vpc_name" {
    filter {
      name = "tag:Name"
      values = ["default-vpc"]
    }
}
```

**Explanation**:

- **Purpose**: This data source fetches information about the existing VPC in your AWS environment.
- **Filter**: We filter based on the **Name** tag, where the value is `"default-vpc"`.

  - This allows us to reference the default VPC without hardcoding its ID.

- **Usage**: Once the VPC data source is defined, we can use `data.aws_vpc.vpc_name.id` in other parts of the Terraform configuration, such as in subnet or EC2 configurations.

**What else can we do?**

- You can filter VPCs by:

  - **CIDR Block**: Example: `cidr_block = "10.0.0.0/16"`.
  - **State**: Filter by VPC state (e.g., `available`, `pending`).
  - **Tags**: You can filter by other tags like `Environment`, `Owner`, etc.

---

#### 2. **Adding the Subnet Data Source**

```hcl
data "aws_subnet" "shared" {
  filter {
    name = "tag:Name"
    values = ["subnetA"]
  }
  vpc_id = data.aws_vpc.vpc_name.id
}
```

**Explanation**:

- **Purpose**: This data source fetches the existing subnet information within the VPC.
- **Filter**: It filters based on the **Name** tag, where the value is `"subnetA"`. This identifies a specific subnet within the VPC.
- **VPC ID Reference**: We link this subnet to the previously fetched VPC using `vpc_id = data.aws_vpc.vpc_name.id`.

**What else can we do?**

- You can filter subnets by:

  - **Availability Zone**: Example: `availability_zone = "us-west-2a"`.
  - **CIDR Block**: Filter subnets by their IP range.
  - **Tags**: Subnets can also be filtered by tags like `Name`, `Environment`, etc.

---

#### 3. **Adding the AMI Data Source**

```hcl
data "aws_ami" "linux2" {
    owners = ["amazon"]
    most_recent = true
    filter {
      name = "name"
      values = ["amzn2-ami-hvm-*-x86_64-gp2"]
    }

    filter {
      name = "virtualization-type"
      values = ["hvm"]
    }
}
```

**Explanation**:

- **Purpose**: This data source retrieves the most recent Amazon Linux 2 AMI ID from AWS.
- **Owners**: We specify `owners = ["amazon"]` to ensure the AMI is an official Amazon-owned image.
- **Filters**:

  - The **name filter** is set to `"amzn2-ami-hvm-*-x86_64-gp2"`, which matches all Amazon Linux 2 AMIs.
  - The **virtualization-type filter** is set to `"hvm"`, ensuring the AMI is compatible with modern EC2 instances that require HVM virtualization.

**What else can we do?**

- Additional filters can be added to further refine the AMI selection:

  - **Architecture**: Example: `architecture = "x86_64"`.
  - **Root Device Type**: Example: `root_device_type = "ebs"`.
  - **Most Recent**: We can always ensure we get the latest version using `most_recent = true`.
  - **Region Specific**: You can set a specific AWS region if needed.

---

#### 4. **Using Data Sources in the EC2 Instance Resource**

```hcl
resource "aws_instance" "example" {
  ami           = data.aws_ami.linux2.id
  instance_type = "t2.micro"
  subnet_id     = data.aws_subnet.shared.id
  tags = {
    Environment = "dev"
  }
}
```

**Explanation**:

- **AMI**: The `ami` field uses the **ID** of the AMI fetched from the `aws_ami` data source (`data.aws_ami.linux2.id`).
- **Instance Type**: This is set to `t2.micro`, a common EC2 instance type for low-cost testing.
- **Subnet ID**: The `subnet_id` is pulled from the `aws_subnet` data source (`data.aws_subnet.shared.id`), which dynamically fetches the correct subnet.
- **Tags**: A simple tag `Environment = "dev"` is applied to the EC2 instance.

**What else can we do?**

- You can specify additional instance configurations like:

  - **Security Groups**: Use `security_group_ids` or `security_groups` to define allowed network access.
  - **Key Pair**: Specify `key_name = "my-key"` for SSH access.
  - **Block Device Mapping**: Configure additional storage using `block_device`.
  - **User Data**: Use `user_data = file("init-script.sh")` for automated instance initialization.

---
