# Hashicorp Cloud Platform

## Problems with the existing tools we used:

- **Login credentials:** We needed to authenticate to AWS using our terminal by entering keys, and they were not stored anywhere.
- **Secrets:** They were encoded but not encrypted unless we used an external service like AWS Secrets Manager.
- **No automation/orchestration layer:** We ran Terraform commands manually with no CI/CD support.
- **Store modules:** We had to upload modules and reuse them beyond third-party sources.
- **Environment:** We had to duplicate code to deploy it in different environments.

## Solved by HCP (GUI-based offering):

- **Inbuilt integration with Git repos:** Automatically checks out the code.
- **Workspaces and projects** for organization.
- **Central place** to store variables, state files, credentials, and more, eliminating the need for a separate remote backend for state files.
- **Private registry** to create and push modules to the Terraform registry.
- **GUI-based interface** for management.

## Procedure for using it:

1.  First, create an **organization** in HCP (the root layer).
    - _Example:_ `YashChavan`
2.  Within the organization, create multiple **projects**, which can be separated by environments or cloud providers.
    - _Example:_ `azure`, `aws`, `gcp`
3.  Inside each project, create multiple **workspaces**.
    - _Example:_ `day1`, `day2`, etc., per project.

> **Note:** A workspace is a collection of Terraform files used together to provision infrastructure.

4.  To use a workspace, you need to create a **workflow**. Types of workflows include:
    1.  **Version control:** Changes made in the connected repository trigger automatic runs with the latest code.
    2.  **CLI-based:** Commands are run from the local terminal, and execution/logs are managed via the GUI.
    3.  **API-based:** Workflows are triggered by making API calls.

## GUI

Website: https://app.terraform.io/login

- Connect a workspace to a GitHub repository by specifying the repo and the directory path.
- Configure basic settings and options, such as when to run `apply`.
- Provide secret variables (e.g., `AWS_SECRET_ACCESS_KEY` and `AWS_ACCESS_KEY`) so HCP can execute and create AWS resources.
- Runs can be triggered manually or automatically based on defined patterns (e.g., changes in a specific directory path). Auto-approval can be configured; otherwise, the UI will prompt for approval before applying changes.

## Mapping a Local Folder to HCP

1.  In your organization settings, select "Terraform CLI" to view the setup documentation.
2.  In the folder you want to connect, run:
    ```
    terraform login
    ```
    This generates a token to paste into the CLI, with an expiry time.
3.  Add the following code block to your Terraform configuration file to set up cloud integration:

    ```hcl
    terraform {
      cloud {
        organization = "YashChavanWeb"
        workspaces {
          name = "yash-chavan-web"
        }
      }
    }
    ```

4.  Subsequent runs initiated via `terraform apply` from your CLI will be visible in the HCP GUI as "Triggered via CLI."
