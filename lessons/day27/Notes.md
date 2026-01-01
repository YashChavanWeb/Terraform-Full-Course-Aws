# Terraform Automation using CI/CD

- Use GitHub Actions to automate the provisioning and management of infrastructure using Terraform with the help of a pipeline.

## CI/CD Pipeline

- A developer will issue a pull request to the repository.
- An approver reviews the feature branch and approves it, triggering the GitHub Actions workflow.
- The workflow will then initiate:
  - **tflint** for linting.
  - **trivy** for security scanning.
- Terraform will plan and apply the changes (if an S3 backend is used for state file management).
- The pipeline will then provision the infrastructure.

## Infrastructure

- **Two-Tier Architecture:**
  1. A user makes a request over the internet.
  2. The request goes to the Application Load Balancer (ALB) on port 80, which resides in a public subnet.
  3. The ALB forwards the request to the internal private subnet (to which it has access).
  4. The EC2 instance processes the request and returns the output to the NAT Gateway in the public subnet.
  5. The NAT Gateway, having internet access, returns the final response to the user.

## Creating the Application

- First, we need to write the code for the two-tier application. It is already written.
- Refer to the blog: [Day-24-Blog](https://terraform-with-aws.hashnode.dev/day-24-scalable-and-fault-tolerant-two-tier-application-using-terraform).
- You can also clone the repository: [Repo](https://github.com/piyushsachdeva/Terraform-Full-Course-Aws).
- Then, go to the `lessons/day27/code` directory for further instructions.

## Setup for Pipeline

- First, run the setup file to configure a remote state file for the application.
- Path: `lessons/day30/code/scripts/setup-backend.sh`

**Commands:**

```bash
# Give CHMOD permissions
chmod +x setup-backend.sh

# Run the setup file
./setup-backend.sh
```

- Update the `backend.tf` file with the name of the created S3 bucket.

> **Note:** We are using an S3 bucket because it supports native state file locking, eliminating the need for DynamoDB.

## Creating the Pipeline

### Setting Up Secret Credentials

1. Go to your repository → **Settings** → **Secrets and variables** → **Actions**.
2. Create environment variables to allow the workflow to interact with AWS.
3. Go to IAM, select a user with sufficient permissions to provision resources, and generate a new Access Key and Secret Key.
4. Create two repository secrets:

   - **Name:** `AWS_ACCESS_KEY_ID`
     **Value:** `<your-access-key-id>`

   - **Name:** `AWS_SECRET_ACCESS_KEY`
     **Value:** `<your-secret-access-key>`

### Environment Setup

1. Go to the **Environments** tab in Settings.
2. Create three environments:
   - `prod` (add a required reviewer)
   - `test`
   - `dev`

## Adding YAML Files

- In the root `.github/workflows/` folder, add the following three YAML files:

  - [day27-github-provisioning.yaml](https://github.com/piyushsachdeva/Terraform-Full-Course-Aws/blob/main/.github/workflows/day27-github-provisioning.yaml)
  - [destroy-day-27.yaml](https://github.com/piyushsachdeva/Terraform-Full-Course-Aws/blob/main/.github/workflows/destroy-day27.yaml)
  - [drift-detection.yaml](https://github.com/piyushsachdeva/Terraform-Full-Course-Aws/blob/main/.github/workflows/drift_detection.yml)

- These YAML files must be placed in the `.github/workflows/` folder to trigger the workflows correctly.

## Testing the Pipeline

- We have multiple `tfvars` files for different environments (e.g., `dev`).
- Make a change in the `tfvars` file for the `dev` environment.
- Create a feature branch and push the code to that branch.
- Issue a pull request and approve it via the GitHub UI.
- Go to the **Actions** tab to view the executed workflows.
- You can check the Load Balancer DNS to verify application health or use the AWS Management Console.

## Testing the Security Scanning

- Go to the executed workflow in the **Actions** tab.
- Review the **Trivy** section to see all reported security vulnerabilities.
