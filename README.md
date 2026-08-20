# Multi-Region Biodata Platform

Production-oriented DevOps for deploying a highly available biodata
application across two AWS regions. Terraform provisions the infrastructure,
Ansible configures the EC2 hosts and deploys the application, and AWS Global
Accelerator provides a stable global entry point with health-based regional
failover.

## Architecture Overview

The primary region is `eu-north-1` and the secondary/DR region is `us-west-2`
by default. Both regions contain a VPC, public subnets, an Application Load
Balancer, an Auto Scaling Group, EC2 application instances, and an encrypted EFS
filesystem. AWS Backup protects each regional EFS filesystem with a daily backup
plan and 35-day retention by default.

![Architecture Diagram](Architecture%20Diagram.jpg)


Global Accelerator has TCP listeners on ports `80` and `443`. TLS termination,
when configured, remains the responsibility of the ALB. Endpoint groups use
HTTP health checks on port `80` and path `/`. If the primary ALB endpoint is
unhealthy, traffic is sent to the secondary endpoint.

## Prerequisites and Tooling

Install the following tools locally or in the CI runner:

- Terraform `>= 1.6.0`
- AWS CLI v2
- Ansible Core
- Python 3.12 for the application tooling
- Docker Engine with Docker Compose v2
- Git

The AWS identity used by Terraform needs permission to manage the resources in
this project, including:

- VPC, subnet, route table, internet gateway, security group
- EC2, AMI copy, Auto Scaling, and key-pair lookup
- Application Load Balancer
- EFS and mount targets
- Global Accelerator
- AWS Backup vaults, plans, selections, and recovery points
- IAM role creation and policy attachment for AWS Backup
- CloudWatch alarms and SNS topics/subscriptions

The deployment also requires an existing EC2 key pair with the same name in
both regions. The default key pair name is `biodata-deploy`. Do not commit a
private key or AWS credentials.

## Repository Structure

```text
.
├── .github/workflows/
│   ├── deploy.yml                    # Terraform validation, plan, and apply
│   ├── app-setup.yml                 # Ansible deployment to EC2 hosts
│   ├── test-primary-alb-failover.yml # Controlled primary failure test
│   └── destroy.yml                   # Approved Terraform teardown
├── ansible/
│   ├── inventory.ini                 # Runtime host inventory
│   ├── site.yml                      # Main configuration playbook
│   └── roles/
│       ├── common/                   # Docker, EFS support, host setup
│       └── app/                      # Application files and Compose startup
├── backend/                          # FastAPI service, migrations, and tests
├── frontend/                         # Next.js application
├── terraform/
│   ├── main.tf                       # Regional infrastructure composition
│   ├── provider.tf                   # Primary, DR, and Global Accelerator providers
│   ├── variable.tf                   # Deployment inputs and defaults
│   ├── output.tf                     # ALB, GA, EFS, and backup outputs
│   ├── monitoring.tf                 # CloudWatch alarms and SNS notifications
│   └── modules/
│       ├── networking/               # VPC, subnets, routes, internet gateway
│       ├── security/                 # Regional security groups
│       ├── alb/                      # ALB, listeners, and target groups
│       ├── asg/                      # EC2 launch template and Auto Scaling
│       ├── efs/                      # Encrypted EFS and mount targets
│       ├── efs-backup/               # AWS Backup vault and daily plan
│       └── global-accelerator/       # Accelerator, listeners, and endpoint groups
├── docker-compose.yml                # Local and host application orchestration
├── Makefile                          # Common local and Ansible commands
└── CONTRACT.md                       # Application API and data contract
```

## Configuration

Terraform variables can be supplied with `-var`, a `terraform.tfvars` file, or
environment variables using the `TF_VAR_` prefix. Important defaults are:

| Variable | Default | Purpose |
|---|---|---|
| `primary_region` | `eu-north-1` | Primary AWS region |
| `dr_region` | `us-west-2` | Secondary/DR AWS region |
| `global_accelerator_region` | `us-west-2` | Provider region for GA API operations |
| `project_name` | `biodata` | Resource name prefix |
| `key_name` | `biodata-deploy` | Existing EC2 key pair name |
| `instance_type` | `t3.medium` | EC2 instance type |
| `target_port` | `3000` | Application port behind the ALBs |
| `alert_email` | `null` | Optional SNS email subscription |

For a non-default deployment, create a local `terraform/terraform.tfvars` file
and do not commit secrets:

```hcl
project_name       = "biodata"
primary_region     = "eu-north-1"
dr_region          = "us-west-2"
key_name           = "biodata-deploy"
alert_email        = "eohoimiracle@gmail.com"
```

## Deployment Execution

### Phase 1: Provision Infrastructure with Terraform

Authenticate the AWS CLI using an IAM role, environment variables, or an AWS
profile. Confirm both regions and the active account before applying:

```bash
aws sts get-caller-identity
aws configure list

cd terraform
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

The apply creates the primary and secondary networking, security groups, EFS,
ALBs, Auto Scaling Groups, AMI copy, Global Accelerator, CloudWatch alarms,
SNS topics, and AWS Backup plans.

Save the access values from Terraform:

```bash
terraform output global_accelerator_dns_name
terraform output global_accelerator_ip_addresses
terraform output primary_alb_dns_name
terraform output dr_alb_dns_name
terraform output primary_efs_backup_vault
terraform output dr_efs_backup_vault
```

### Phase 2: Configure Hosts and Deploy the Application with Ansible

Terraform creates the EC2 hosts, but Ansible installs/configures Docker and
deploys the Compose application. The normal CI workflow discovers a live host
and writes the runtime inventory. For a local run, update
`ansible/inventory.ini` with a reachable EC2 public IP and the correct SSH key:

```ini
[target_vm]
primary ansible_host=PRIMARY_EC2_PUBLIC_IP ansible_user=ubuntu \
  ansible_ssh_private_key_file=/path/to/biodata-deploy.pem
```

Run the full playbook against each regional host or inventory group:

```bash
ansible-playbook -i ansible/inventory.ini ansible/site.yml
```

To force application provisioning when the readiness checks detect an existing
installation:

```bash
ansible-playbook -i ansible/inventory.ini ansible/site.yml -e force_deploy=true
```

The repository also provides equivalent Make targets:

```bash
make site-deploy
make app-deploy
```

Repeat the host configuration for the secondary region. Both regions must have
a healthy ALB target before failover testing.

### Phase 3: Access the Application Through Global Accelerator

Global Accelerator provides the stable DNS name. Retrieve it from Terraform and
open it in a browser or use it in a health request:

```bash
GA_DNS_NAME=$(terraform -chdir=terraform output -raw global_accelerator_dns_name)
echo "https://${GA_DNS_NAME}"
curl -i "http://${GA_DNS_NAME}/health"
```

The application health endpoint is `/health`. The ALB and Global Accelerator
health checks use `/` as configured by the Terraform module; the application
must return a successful response at that path for the endpoint to remain
healthy.

## Failover and High Availability Demonstration

This is the grading proof for regional failover. Perform it during a controlled
test window because it intentionally removes the primary service from traffic.

### 1. Confirm both endpoints are healthy

Check the Global Accelerator listener and endpoint groups in the AWS console, or
use the CLI:

```bash
GA_ARN=$(aws globalaccelerator list-accelerators \
  --query 'Accelerators[?Name==`biodata-global`].AcceleratorArn | [0]' \
  --output text)

aws globalaccelerator describe-accelerator --accelerator-arn "$GA_ARN"
aws globalaccelerator list-listeners --accelerator-arn "$GA_ARN"
```

Confirm that the primary and secondary ALB target groups are healthy before
starting the test.

### 2. Stop the primary application instance

Identify the primary Auto Scaling Group instance:

```bash
PRIMARY_INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups \
  --region eu-north-1 \
  --auto-scaling-group-names biodata-primary-asg \
  --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`].InstanceId | [0]' \
  --output text)

aws ec2 stop-instances \
  --region eu-north-1 \
  --instance-ids "$PRIMARY_INSTANCE_ID"
```

Because the Auto Scaling Group is designed to replace failed instances, stopping
one instance normally demonstrates **instance recovery**. To demonstrate
**cross-region Global Accelerator failover**, temporarily make the primary ALB
unhealthy by stopping or isolating all primary application targets, or set the
primary ASG desired capacity to zero during the controlled test. Do not leave
the primary ASG at zero after the test.

The existing workflow
`.github/workflows/test-primary-alb-failover.yml` provides a safer replacement
test. It requires explicit confirmation, terminates one primary instance,
waits for Auto Scaling to launch a replacement, and verifies that the new target
becomes healthy.

### 3. Observe health detection and rerouting

Poll the primary ALB target health while requesting the Global Accelerator DNS
name repeatedly:

```bash
for attempt in {1..30}; do
  date -u
  curl --silent --show-error --connect-timeout 5 \
    -o /dev/null -w 'HTTP %{http_code}\n' \
    "http://${GA_DNS_NAME}/health" || true
  sleep 10
done
```

In the AWS console, observe the primary endpoint group transition to unhealthy
and the secondary endpoint receive traffic. The expected result is that the
Global Accelerator DNS name continues responding while traffic is served by
the secondary ALB after health-check detection. Some connection retries may be
needed during convergence; the design avoids requiring a DNS change.

### 4. Restore the primary region

Start the stopped instance or restore the primary ASG desired capacity, then
wait for the primary ALB target and Global Accelerator endpoint to become
healthy again:

```bash
aws autoscaling update-auto-scaling-group \
  --region eu-north-1 \
  --auto-scaling-group-name biodata-primary-asg \
  --desired-capacity 1
```

Verify both regional target groups are healthy before ending the test.

## EFS Backup and Recovery

Terraform creates one AWS Backup vault and daily backup plan per region. The
default retention is 35 days. Inspect recovery points with:

```bash
aws backup list-backup-vaults --region eu-north-1
aws backup list-recovery-points-by-backup-vault \
  --region eu-north-1 \
  --backup-vault-name biodata-primary-efs-vault
```

The backup configuration protects EFS recovery points. It does not replicate a
live EFS filesystem between regions; a cross-region restore remains an explicit
recovery operation and should be tested as part of the organization's recovery
runbook.

## Cleanup and Destruction

Destroying the Terraform workspace removes the Terraform-managed infrastructure
including both regional stacks, Global Accelerator, backup plans, and backup
vaults. Ensure required recovery points and application data have been retained
before destruction.

From the Terraform directory:

```bash
terraform plan -destroy
terraform destroy
```

For CI-managed environments, use the protected GitHub Actions destroy workflow.
It requires the workflow confirmation value and may require approval from the
`terraform-destroy` environment reviewers.

## Local Application Development

The application can also run locally without AWS:

```bash
make up
```

Then open `http://localhost:3000`. The backend health endpoint is available at
`http://localhost:8000/health`. Run the project checks with:

```bash
make lint
make test
```

## Security and Operational Notes

- Keep AWS credentials, Terraform Cloud tokens, SSH private keys, and
  `terraform.tfvars` secrets out of Git.
- Restrict SSH access and application security-group ingress for production use.
- Confirm SNS email subscriptions after configuring `alert_email`.
- Define formal recovery time and recovery point objectives before production
  adoption.
- Test both instance replacement and regional failover regularly; they validate
  different parts of the design.
