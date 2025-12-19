# Terraform Real-time Project

## Project: End-to-End Kubernetes Cluster Infrastructure

### Infrastructure Components:
- **VPC** - Virtual Private Cloud for network isolation
- **Subnets** - Public and private subnet configuration
- **OIDC** - OpenID Connect for authentication
- **Secret Manager** - For managing keys used by the EKS Cluster

## Topics Covered:
- Custom Modules in Terraform

## Modules in Terraform
- **Definition**: Reusable pieces of Terraform code that can be shared and used across multiple projects
- **Purpose**: Similar to functions in programming languages, but specifically for infrastructure configuration

### How Modules Differ from Functions
- Terraform provides built-in functions for configuration manipulation
- Modules are used when creating reusable infrastructure code patterns
- Modules act as **blueprints for infrastructure** that can be instantiated multiple times

## Types of Modules

1. **Public Modules** - Officially maintained by AWS / Hashicorp / Azure
2. **Partner Modules** - Jointly managed by Hashicorp and technology partners
3. **Custom Modules** - Created and maintained by individuals or organizations

### Custom Module Development Process:
1. Create a GitHub repository
2. Publish the module to the repository
3. Tag releases for version management
4. Lock critical values within the module to prevent unintended changes

## Structure of a Custom Module

### Basic File Structure:
```
module-directory/
├── main.tf          # Primary resource definitions
├── variables.tf     # Input variables
├── outputs.tf       # Output values
├── versions.tf      # Terraform and provider versions
└── README.md        # Documentation
```

### Module Communication:
- **variables.tf** - Defines input parameters (like function parameters)
- **outputs.tf** - Defines values to expose to parent module (like return values)
- **Dependencies** - Modules can depend on resources from other modules

### Module Source Specification:
- Local modules: `source = "./modules/vpc"`
- Remote modules: `source = "github.com/username/repo"`

## Example: VPC Module Implementation

### Module Code (`/modules/vpc/main.tf`):
```terraform
# VPC Resource
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-vpc"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-igw"
    }
  )
}
```

### Root Module Usage (`/code/main.tf`):
```terraform
# Custom VPC Module Instantiation
module "vpc" {
  source = "./modules/vpc"

  # Input variables
  name_prefix     = var.cluster_name
  vpc_cidr        = var.vpc_cidr
  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  enable_nat_gateway = true
  single_nat_gateway = true

  # Required tags for EKS
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
    Project     = "EKS-Day20"
  }
}
```

**Key Concept**: Variables defined in the root module are passed to the child module, which uses them to configure resources.

## Example: IAM Module with Hardcoded Values

### Hardcoded Policy in Module (`/modules/iam/main.tf`):
```terraform
# EKS Cluster IAM Role
resource "aws_iam_role" "cluster" {
  name_prefix = "${var.cluster_name}-cluster-"

  # Hardcoded assume role policy
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}
```

**Note**: Hardcoding certain values (like policies) in modules prevents unintended modifications and ensures consistency.

### Module Usage in Root Module:
```terraform
# Custom IAM Module Instantiation
module "iam" {
  source = "./modules/iam"

  cluster_name = var.cluster_name

  tags = {
    Environment = var.environment
    Terraform   = "true"
    Project     = "EKS-Day20"
  }
}
```

**Important**: Modules communicate with each other through the root module, not directly.

## Project Overview

This project demonstrates a production-ready EKS cluster deployment using custom Terraform modules instead of public community modules.

### Network Flow Diagram:
```
Internet → IGW → Public Subnets → NAT Gateway → Private Subnets → EKS
        ↑                                         ↓
        └─────────────────────────────────────────┘
           Pods reach internet via NAT Gateway
```

### Custom Module Breakdown:

## Module 1: VPC Module (`modules/vpc/`)

### Purpose:
Creates the networking foundation for the EKS cluster.

### Why We Need It:
- EKS requires specific VPC configuration with public and private subnets
- Proper subnet tagging is critical for Kubernetes service discovery
- NAT Gateway enables private nodes to access the internet (for pulling images, updates)

### Resources Created:
- **Internet Gateway** - Required for public subnet internet access
- **NAT Gateway** - Allows private subnets (EKS nodes) to reach the internet without exposing them
- **Multiple AZs** - High availability - if one AZ fails, others continue working
- **Subnet Tagging** - Kubernetes uses these tags to automatically create load balancers

---

## Module 2: IAM Module (`modules/iam/`)

### Purpose:
Creates IAM roles and policies for the EKS cluster and worker nodes.

### Why We Need It:
- EKS control plane needs permissions to manage AWS resources
- Worker nodes need permissions to join the cluster and run workloads
- OIDC enables pods to assume IAM roles (IRSA - IAM Roles for Service Accounts)

### Resources Created:
1. **EKS Cluster IAM Role**
2. **EKS Node Group IAM Role**
3. **IAM Policy Attachments** (AWS managed policies):
   - `AmazonEKSClusterPolicy`
   - `AmazonEKSVPCResourceController`
   - `AmazonEKSWorkerNodePolicy`
   - `AmazonEKS_CNI_Policy`
   - `AmazonEC2ContainerRegistryReadOnly`

### IAM Role Breakdown:
- **Cluster Role**: EKS control plane needs to create/manage load balancers, security groups
- **Node Role**: Worker nodes need to pull container images, register with cluster
- **Separate Roles**: Principle of least privilege - different permissions for different components

### How IAM Works:
```
EKS Cluster → Assumes Cluster Role → Creates Load Balancers, Security Groups
Worker Nodes → Assumes Node Role → Pulls Images, Joins Cluster, Runs Pods
```

---

## Module 3: EKS Module (`modules/eks/`)

### Purpose:
Creates the Kubernetes cluster and worker nodes.

### Why We Need It:
- Provisions the actual Kubernetes control plane
- Creates managed node groups (worker nodes)
- Configures cluster security, logging, and encryption

### Key Security Components:

#### 1. KMS Encryption:
```terraform
encryption_config {
  resources = ["secrets"]  # Encrypts Kubernetes secrets in etcd
}
```
- **Why**: Kubernetes secrets contain sensitive data (passwords, tokens)
- **Benefit**: Even if someone accesses the etcd database, secrets remain encrypted

#### 2. CloudWatch Logs:
```terraform
enabled_cluster_log_types = [
  "api", 
  "audit", 
  "authenticator", 
  "controllerManager", 
  "scheduler"
]
```
- **Why**: Monitor cluster health, troubleshoot issues, security audits
- **Benefit**: Centralized logging for debugging and compliance

---

### Module Interaction Pattern:
```
Root Module (main.tf)
    ├── Module: VPC (creates network foundation)
    ├── Module: IAM (creates security roles)
    └── Module: EKS (creates Kubernetes cluster)
        └── Uses VPC outputs and IAM roles
```
