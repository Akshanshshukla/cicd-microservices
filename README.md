# CI/CD Pipeline Automation for Microservices Deployment

A beginner-friendly portfolio project showing repeatable tests, container builds, CI in GitHub Actions and Jenkins, and optional AWS deployment with Terraform and Amazon ECS Fargate.

## What is included

- `services/orders` and `services/catalog`: independent FastAPI services.
- `deploy/nginx`: small gateway that exposes both services through one local or cloud endpoint.
- `docker-compose.yml`: starts the three containers for local smoke testing.
- `Jenkinsfile`: unit tests, image builds, and gateway smoke tests (Linux Jenkins agent with Docker).
- `.github/workflows/ci.yml`: tests and builds all images on pushes and pull requests. It does not publish images or deploy.
- `terraform/`: ECR repositories, a least-purpose ECS task execution role, a restricted security group, and one Fargate task with three containers. Terraform does not run automatically.

## Prerequisites

For local work: Windows 10/11, Git, Python 3.12, and Docker Desktop with its Linux container engine. For AWS: an AWS account, AWS CLI v2, Terraform 1.6+, and credentials configured through an AWS profile or SSO. You do not need AWS for the local demo or GitHub CI.

## Run locally (PowerShell)

From the repository folder:

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements-dev.txt
python -m pytest -q tests
docker compose up --build -d
```

If PowerShell blocks activation, run this once in the current terminal, then activate again:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Check the gateway and both services:

```powershell
Invoke-RestMethod http://localhost:8080/health
Invoke-RestMethod http://localhost:8080/api/orders
Invoke-RestMethod http://localhost:8080/api/catalog
```

Direct service endpoints are available on ports 8000 and 8001. Stop the stack when finished:

```powershell
docker compose down
```

## Run locally (Windows CMD)

```bat
py -3.12 -m venv .venv
.venv\Scripts\activate.bat
python -m pip install --upgrade pip
python -m pip install -r requirements-dev.txt
python -m pytest -q tests
docker compose up --build -d
curl http://localhost:8080/health
curl http://localhost:8080/api/orders
curl http://localhost:8080/api/catalog
docker compose down
```

## GitHub Actions and Jenkins

Create an empty repository on GitHub, then run these commands from this project folder (replace the URL with your new repository URL):

```powershell
git init -b main
git add .
git commit -m "Add microservices CI/CD portfolio demo"
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPOSITORY.git
git push -u origin main
```

The same commands work in Windows CMD. The workflow runs the unit tests and builds all three images for pushes to `main`, pull requests, and manual workflow runs. No AWS keys or GitHub secrets are needed for CI.

For Jenkins, use a Linux agent with Python 3.12, Docker Engine, the Docker Compose v2 plugin, and the Workspace Cleanup plugin. Configure the job as a Pipeline from SCM and select this repository's `Jenkinsfile`. The pipeline installs development requirements, tests, builds images, starts the stack, and smoke-tests the gateway before cleaning up. It intentionally has no AWS deployment credentials or deploy stage.

## Optional AWS deployment (costs money)

The AWS path creates ECR repositories, IAM resources, an ECS cluster and one always-on Fargate task with a public IPv4 address. Fargate, public IPv4, and image storage can incur charges while it exists; pricing varies by region. Check current AWS pricing before proceeding. Keep the service running only while you need the demo, then destroy it. The Terraform security group defaults to `127.0.0.1/32`, which blocks your real public connection until you set your own public IPv4 CIDR.

### 1. Configure AWS access securely

Use AWS IAM Identity Center/SSO or a named AWS CLI profile. Do not put access keys in this repository, a `.tf` file, or a command recorded in shell history.

PowerShell:

```powershell
aws configure sso --profile portfolio
aws sso login --profile portfolio
$env:AWS_PROFILE = "portfolio"
aws sts get-caller-identity
```

CMD:

```bat
aws configure sso --profile portfolio
aws sso login --profile portfolio
set AWS_PROFILE=portfolio
aws sts get-caller-identity
```

### 2. Create infrastructure

In `terraform/`, initialize and inspect the plan first. Replace `YOUR_PUBLIC_IPV4` with your current public IPv4 address (find it through a trusted IP-check service) and preserve `/32` so only that address can reach the demo.

PowerShell:

```powershell
cd terraform
$env:TF_VAR_allowed_cidr = "YOUR_PUBLIC_IPV4/32"
terraform init
terraform plan -out=tfplan
terraform apply tfplan
terraform output -json ecr_repository_urls
```

CMD:

```bat
cd terraform
set TF_VAR_allowed_cidr=YOUR_PUBLIC_IPV4/32
terraform init
terraform plan -out=tfplan
terraform apply tfplan
terraform output -json ecr_repository_urls
```

Review the plan and AWS charges before `apply`. This first apply creates the repositories and supporting resources with the ECS desired count at zero, so it does not start Fargate compute. Terraform state contains infrastructure identifiers and must be kept private. This example uses local state; back it up securely and do not commit it. The ignored state file is intentionally excluded from Git.

### 3. Build and push images

In a second terminal at the repository root, use the AWS account number and region from your AWS profile. Use a unique image tag for every release; ECR tags are immutable.

PowerShell (replace the two placeholders):

```powershell
$account = "YOUR_AWS_ACCOUNT_ID"
$region = "us-east-1"
$tag = "v1"
$registry = "$account.dkr.ecr.$region.amazonaws.com"
aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $registry
docker build -t "$registry/portfolio-microservices-orders:$tag" .\services\orders
docker build -t "$registry/portfolio-microservices-catalog:$tag" .\services\catalog
docker build -t "$registry/portfolio-microservices-gateway:$tag" .\deploy\nginx
docker push "$registry/portfolio-microservices-orders:$tag"
docker push "$registry/portfolio-microservices-catalog:$tag"
docker push "$registry/portfolio-microservices-gateway:$tag"
```

CMD:

```bat
set ACCOUNT=YOUR_AWS_ACCOUNT_ID
set REGION=us-east-1
set TAG=v1
set REGISTRY=%ACCOUNT%.dkr.ecr.%REGION%.amazonaws.com
aws ecr get-login-password --region %REGION% | docker login --username AWS --password-stdin %REGISTRY%
docker build -t %REGISTRY%/portfolio-microservices-orders:%TAG% services\orders
docker build -t %REGISTRY%/portfolio-microservices-catalog:%TAG% services\catalog
docker build -t %REGISTRY%/portfolio-microservices-gateway:%TAG% deploy\nginx
docker push %REGISTRY%/portfolio-microservices-orders:%TAG%
docker push %REGISTRY%/portfolio-microservices-catalog:%TAG%
docker push %REGISTRY%/portfolio-microservices-gateway:%TAG%
```

Update `image_tag` in `terraform/terraform.tfvars` (create this untracked file) to the same tag. Apply the update:

```powershell
Set-Content terraform\terraform.tfvars 'image_tag = "v1"' 'desired_count = 1' 'allowed_cidr = "YOUR_PUBLIC_IPV4/32"'
terraform -chdir=terraform plan -out=tfplan
terraform -chdir=terraform apply tfplan
```

Then retrieve the running task's public IP from ECS in the AWS Console (ECS → cluster → service → Tasks → task → Networking). Open `http://PUBLIC_TASK_IP:8080/health` and `/api/orders` or `/api/catalog`. The task may take a few minutes to become healthy. The IP can change when ECS replaces the task.

### Roll back safely

Keep the previously known-good immutable image tag (for example `v1`). To roll back from `v2`, change `image_tag` in `terraform/terraform.tfvars` back to `v1`, then run `terraform plan` and review it before `terraform apply`. ECS starts the prior task definition using the old images. Verify the health and API endpoints. This is a demo rollback process, not a zero-downtime production guarantee.

### Remove AWS resources

When done, from the repository root:

```powershell
terraform -chdir=terraform destroy
```

CMD:

```bat
terraform -chdir=terraform destroy
```

Review and confirm the destroy plan. This removes the ECS resources and ECR repositories, including demo images. Confirm the ECS service is gone to stop ongoing compute and public IPv4 charges.

## Portfolio/resume accuracy

This repository implements the demo workflows and AWS infrastructure definitions. Do not claim it was deployed, operated at scale, or reduced failures by a measured percentage unless you actually ran it and recorded evidence. A truthful resume bullet after local validation could say: “Built a sample CI pipeline for two containerized services using GitHub Actions, Jenkins, Docker Compose, automated tests, and Terraform definitions for an optional AWS ECS deployment.” Add deployment or impact claims only after completing those steps and measuring them.

## Repository layout

```text
services/                 Orders and catalog APIs
deploy/nginx/             Shared HTTP gateway
tests/                    Automated unit tests
.github/workflows/        GitHub Actions CI
Jenkinsfile               Jenkins CI pipeline
terraform/                Optional AWS infrastructure
docker-compose.yml        Local multi-container environment
```
