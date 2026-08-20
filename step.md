# Deployment Blueprint

This project provisions AWS infrastructure, installs Docker tooling and EFS support, and deploys the biodata application stack through Terraform and Ansible.

---

## 1. Project Structure

```text
.
├── .github/
│   └── workflows/
│       └── deploy.yml         # Deployment pipeline for Terraform + Ansible
├── ansible/
│   ├── inventory.ini           # Target VM inventory for Ansible
│   ├── site.yml                # Main Ansible playbook
│   └── roles/
│       ├── app/
│       └── common/
├── backend/                    # FastAPI backend service
├── frontend/                   # Next.js frontend service
├── docker-compose.yml          # Local app orchestration
├── Makefile                    # Common local and deployment commands
├── README.md                   # Project usage and setup docs
└── step.md                     # This deployment blueprint
```

---

## 2. Setup Guide

### Step 2.1: Configure Terraform Cloud
1. Open [app.terraform.io](https://terraform.io) and sign in.
2. Create a new workspace using the CLI-driven workflow.
3. Set the execution mode to Local and save the configuration.
4. Create a Terraform API token and keep it safe for GitHub Actions.

### Step 2.2: Add GitHub Secrets and Variables
Add the following repository secrets:
- `TF_API_TOKEN`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `VM_SSH_PRIVATE_KEY`

The existing dedicated key pair named `biodata-deploy` is used in both regions.
Store its matching private key file as the `VM_SSH_PRIVATE_KEY` GitHub secret.
Terraform reads the regional key pairs and does not manage or destroy them. Set
the Terraform Cloud variable `key_name` only if a different existing dedicated
pair name is required. Do not commit the private key.

Add the following repository variables:
- `MY_VPC_ID`
- `MY_SUBNET_ID`

### Step 2.3: Trigger Deployment
Push changes to the default branch to start the deployment workflow.

```bash
git add .
git commit -m "feat: deploy application stack"
git push origin main
```

Then monitor the GitHub Actions deployment run until it succeeds.

### Step 2.4: Validate Deployment
1. Read the output of the Terraform step to obtain the VM public IP.
2. Access the frontend through the ALB DNS name exported by Terraform.
3. Confirm the frontend target is healthy in the ALB target group and inspect the Compose logs on the instance if needed.

### Step 2.5: Tear Down the Environment
When the project is complete, open the `Terraform Cloud + AWS Destroy` workflow in GitHub Actions and select **Run workflow**. Enter `DESTROY` exactly in the confirmation field and provide a reason. The workflow will:
1. Initialize and validate Terraform.
2. Create a destroy plan for the Terraform Cloud workspace.
3. Wait for approval if the `terraform-destroy` GitHub environment is configured with required reviewers.
4. Apply the destroy plan and remove Terraform-managed primary and DR infrastructure.

The destroy workflow does not remove resources that are outside the Terraform state, and it does not delete the Terraform Cloud workspace itself. Back up any data that must be retained before running it.

---

## 3. Infrastructure Layer

### Terraform
The Terraform configuration provisions the AWS VPC, ALB, EFS, and Docker Compose ASG platform.

### Ansible
The main playbook in `ansible/site.yml` runs the application setup roles in order:
- `common`
- `app`

---

## 4. Deployment Workflow

The GitHub Actions workflow in `.github/workflows/deploy.yml` performs the full release flow:
1. Authenticate to AWS.
2. Initialize and apply Terraform.
3. Install Ansible and deploy the Docker Compose application.
4. Build the inventory file for the target VM.
5. Run `make site-deploy` to provision and deploy the app stack.

This workflow is intentionally limited to deployment and application setup only.
