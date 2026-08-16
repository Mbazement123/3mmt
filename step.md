# End-to-End Automation Blueprint: Separated CD & Manual Chaos Pipelines

This layout uses **Terraform Cloud** (CLI-driven, Local Execution Mode) for state tracking, **GitHub Actions** for pipeline scheduling, and agentless **Ansible** to manage application configuration, Grafana monitoring, and manual Chaos Engineering injection.

---

## 1. Project Directory Structure
Organize your GitHub repository files exactly like this before pushing to production:
```text
.
├── .github/
│   └── workflows/
│       ├── deploy.yml         # Track 1: Safe Deployment Pipeline (Triggers on Git Push)
│       └── chaos-trigger.yml  # Track 2: Manual Disaster Pipeline (Triggers on Button Click)
├── providers.tf                # Terraform Cloud workspace & AWS settings
├── variables.tf                # Input declarations for your network
├── main.tf                     # Core AWS infrastructure components
├── outputs.tf                  # Returns the server IP to GitHub
├── playbook.yml                # Core server config & Observability installation
├── chaos.yml                   # Disaster Recovery Chaos engineering tasks
├── grafana-alerting.yml        # Declarative Grafana Slack/Discord alert rules
└── Dockerfile                  # Your web application build instructions
```

---

## 2. Step-by-Step Implementation Guide

Follow these steps in order to set up, authenticate, and run your automation pipeline without any manual configuration bugs.

### Step 2.1: Configure Your Terraform Cloud Workspace
1. Navigate to [app.terraform.io](https://terraform.io) and log into your account.
2. Click **Create a new workspace**.
3. Choose **CLI-driven Workflow** as your configuration structure. Name your workspace `k8s-dr-project`.
4. Once created, click on **Settings** in the left sidebar menu, then select **General**.
5. Scroll down to **Execution Mode**, switch it from *Remote* to **Local**, and click **Save settings**.
6. Click on your profile icon in the bottom left corner, go to **User settings** -> **Tokens**, click **Create an API token**, copy the generated text string, and save it safely.

### Step 2.2: Add Secrets & Variables to Your GitHub Repository
Open your code repository on GitHub and click on **Settings** -> **Secrets and variables** -> **Actions**.

#### Add these tokens under the "Secrets" tab:
* `TF_API_TOKEN`: Paste the User API token you generated inside Terraform Cloud.
* `AWS_ACCESS_KEY_ID`: Your IAM programmatic user access key ID.
* `AWS_SECRET_ACCESS_KEY`: Your IAM programmatic user secret access key password.
* `VM_SSH_PRIVATE_KEY`: Paste the complete plain-text block of your `.pem` key pair file used to connect to your AWS EC2 servers.
* `ALERT_WEBHOOK_URL`: Your unique Slack Incoming Webhook url string or Discord automation webhook url.

#### Add these paths under the "Variables" tab (Right next to the Secrets tab):
* `MY_VPC_ID`: Paste your target AWS VPC string (e.g., `vpc-0123456789abcdef0`).
* `MY_SUBNET_ID`: Paste your target AWS Subnet string where the VM should deploy (e.g., `subnet-9876543210fedcba0`).

### Step 2.3: Push Code to Trigger Track 1 (Continuous Deployment)
1. Write the code files provided below into your local project directory.
2. Commit your files to Git and push them straight up to your remote repository's default branch:
   ```bash
   git add .
   git commit -m "feat: complete deployment and monitoring cluster architecture"
   git push origin main
   ```
3. Open your GitHub Repository webpage, click on the **Actions** tab, and monitor the `TFC State and Ansible Observability Deployment` job run (or `deploy.yml`) until it finishes successfully with all green checkmarks.

### Step 2.4: Validate Visual Monitoring Dashboards
1. Copy the **Public IP Address** output printed at the end of your successful GitHub Actions deployment logs.
2. Open your web browser and navigate to port `31000` on that IP (e.g., `http://54.210.43.8:31000`).
3. You will land directly on your active **Grafana Monitoring Dashboard** displaying live node metrics.

### Step 2.5: Trigger Track 2 (Manual Chaos Disaster Test)
1. On your GitHub Repository webpage, click on the **Actions** tab at the top of the screen.
2. On the left sidebar list, click on **Manual Chaos & DR Simulation**.
3. Locate the white **"Run workflow"** dropdown menu button on the right side of your dashboard panel.
4. Select your target branch (e.g., `main`) and click the green **Run workflow** button.
5. *What the chaos workflow does:* by default the workflow triggers `ansible/chaos.yml` on the provisioned host. It will simulate a failure (scale down or terminate app components), pause for observation, then perform restoration steps. The exact actions depend on `ansible/chaos.yml` variables (e.g. `fail_stage`).

6. *Important:* The repository now uses `site.yml` and role-based Ansible tasks. Before running the chaos workflow, confirm `ansible/chaos.yml` is targeting the correct deployment names (our manifests deploy `biodata-frontend`, `biodata-backend`, and `biodata-db`). If `chaos.yml` still references older names (e.g., `dr-web-app`), update it to target `biodata-frontend` or `biodata-backend` as appropriate.

7. Example local command to run the chaos playbook against your target VM (use the same `inventory.ini` built in CI):

```bash
# Simulate failover stage locally
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ansible/inventory.ini ansible/chaos.yml -e "fail_stage=failover"

# Simulate failback stage locally
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ansible/inventory.ini ansible/chaos.yml -e "fail_stage=failback"
```

8. Quick verification commands after a chaos run (on your machine or in CI via Ansible):

```bash
# View pods, replication, and recent events
kubectl get pods -n default
kubectl get deployments -n default
kubectl describe deployment biodata-backend -n default
kubectl get events -A --sort-by='.lastTimestamp'

# Check Grafana for alert delivery (Grafana on NodePort 31000)
curl -s http://<VM_IP>:31000
```

### Expected Results When Running the Workflows

- Deployment pipeline (`deploy.yml` / `make site-deploy`):
   - Terraform provisions the VM and outputs its public IP.
   - Ansible `site.yml` runs roles `common`, `k8s_setup`, `monitoring`, `app` in order.
   - Minikube is started on the VM and Docker images are built inside Minikube using `docker compose build`.
   - `biodata-frontend`, `biodata-backend`, and `biodata-db` are created in `default` namespace.
   - Prometheus & Grafana (`kube-prometheus-stack`) are installed in the `monitoring` namespace and Grafana is reachable on NodePort `31000`.

- Chaos pipeline (`chaos-trigger.yml` / `ansible/chaos.yml`):
   - The workflow scales down or kills the targeted deployment (frontend or backend) to simulate a failure.
   - Within ~30s Prometheus/Grafana will detect missing replicas and alert rules will fire.
   - Grafana alerting will send a notification to the configured `ALERT_WEBHOOK_URL` (Slack/Discord) per `grafana-alerting.yml`.
   - Recovery actions (failback or automated Ansible remediation) will restore replicas and services.
   - Kubernetes auto-healing (liveness/readiness probes) will restart containers that fail their probes; final state should show `REPLICAS` equal to desired counts (frontend/backend = 2).

### Troubleshooting / Verification Tips

- If pods enter `ImagePullBackOff`, ensure images were built into the Minikube Docker daemon (use `make compose-build` or run `eval $(minikube docker-env)` on the VM and build). Our manifests set `imagePullPolicy: IfNotPresent` to prefer local images.
- If Grafana doesn't show alerts, verify `ansible/grafana-alerting.yml` was templated with a valid `ALERT_WEBHOOK_URL` and applied to the `monitoring` namespace.
- Use `kubectl logs -n monitoring deployment/kube-prometheus-stack-grafana` to inspect Grafana logs.


---

## 3. Infrastructure Layer (Terraform)

### `providers.tf`


### `variables.tf`


### `main.tf`


### `outputs.tf`


## 4. Configuration & Monitoring Layer (Ansible)

### `playbook.yml`

## grafana-alerting.yml

## chaos.yml


## Orchestration Pipelines (GitHub Actions)Track 1: Safe Deployment Pipeline (.github/workflows/deploy.yml)


##  Manual Disaster Pipeline .github/workflows/chaos-trigger.yml
