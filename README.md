# Multi-Tier Java Web Application – Infrastructure & CI/CD on AWS

A DevOps practice project: a multi-tier Java web application (based on the open-source *vprofile* course app) that I provision with **Terraform**, configure with **Ansible**, containerise with **Docker** and deploy through a **Jenkins** pipeline to **AWS**.

> Status: learning/portfolio project. See [Known limitations](#known-limitations--next-steps) for what I would do differently in production.

## Architecture

```
                 Internet
                    │ 80 → 301 → 443 (ACM certificate)
              ┌─────▼─────┐
              │    ALB    │  (alb-sg: only HTTP/HTTPS from the internet)
              └─────┬─────┘
                    │ 8080
              ┌─────▼─────┐        ┌──────────┐ ┌───────────┐ ┌──────────┐
              │  Tomcat   │───────►│  MySQL   │ │ Memcached │ │ RabbitMQ │
              │ (Docker)  │        └──────────┘ └───────────┘ │ (Docker) │
              └───────────┘        3306          11211        └──────────┘
   Nginx (optional reverse proxy, port 80)                       5672
```

| Tier | Technology | Runs on |
|------|-----------|---------|
| Load balancer | AWS ALB, HTTPS via ACM, HTTP→HTTPS redirect | managed |
| App server | Tomcat 9 (Docker image from ECR) | EC2 |
| Database | MySQL | EC2 |
| Cache | Memcached | EC2 |
| Message queue | RabbitMQ (Docker) | EC2 |
| Reverse proxy | Nginx (optional) | EC2 |

## Repository layout

| Path | Content |
|------|---------|
| `terraform/` | EC2 instances, security groups, ALB + listeners, S3 remote state, generated Ansible inventory |
| `ansible/` | Playbooks for MySQL, Memcached, RabbitMQ, Nginx, Docker; `deploy.yml` rolls out the app image |
| `jenkins/` | Jenkins plugins list, app Dockerfile |
| `Jenkinsfile` | CI/CD pipeline |
| `vagrant-vm/` | Local five-VM setup used before moving to AWS |
| `app.Dockerfile` | Multi-stage build: Maven → Tomcat |

## How to run

Prerequisites: AWS account, Terraform ≥ 1.8, Ansible, an EC2 key pair, an ACM certificate.

```bash
# 1. Infrastructure
cd terraform
cp terraform.tfvars.example terraform.tfvars   # fill in vpc_id, certificate_arn, admin_cidr
terraform init
terraform plan
terraform apply          # also writes ../ansible/hosts

# 2. Secrets for Ansible
cd ../ansible
cp vars/secrets.yml.example vars/secrets.yml
ansible-vault encrypt vars/secrets.yml
ansible-galaxy collection install -r requirements.yml

# 3. Configure servers
ansible-playbook -i hosts ansible_playbook.yml --ask-vault-pass
```

Deployments of new application versions are done by the Jenkins pipeline (below).

## CI/CD pipeline (Jenkins)

1. **Checkout** from GitHub
2. **Unit tests** (Maven, in a throw-away container)
3. **Get AWS account ID** (via `aws sts`, so no account ID in the code)
4. **Build Docker image** (`app.Dockerfile`, tagged with the build number)
5. **Push to ECR**
6. **Update Ansible inventory** – looks up the running Tomcat instance with the AWS CLI
7. **Deploy with Ansible** – pulls the image from ECR and restarts the container

AWS credentials and the SSH key are stored as Jenkins credentials and injected with credentials binding.

## Security notes

- Security groups follow least privilege: only the ALB is public; SSH and the RabbitMQ UI are limited to `admin_cidr`; MySQL, Memcached and RabbitMQ are reachable only from the servers themselves (use the **private** IPs from `terraform output private_ips`).
- Terraform state is stored in S3 (encrypted).
- Secrets (DB password) live in an Ansible Vault file, not in the repository. Keys, state files and `terraform.tfvars` are in `.gitignore`.
- TLS policy: `ELBSecurityPolicy-TLS13-1-2-2021-06`.

## Known limitations & next steps

- Servers sit in public subnets with public IPs; production would use private subnets, a bastion/SSM and NAT.
- MySQL runs on an EC2 instance; RDS would remove the patching/backup burden.
- Single instance per tier, no auto scaling.
- `StrictHostKeyChecking=no` in the deploy stage – acceptable for a lab, should use known hosts.
- No DynamoDB state locking yet (commented in `terraform/main.tf`).
- Monitoring (Prometheus/Grafana) is set up separately and not part of this repository yet.
- Next: Kubernetes deployment, additional pipeline checks (`terraform validate`, `ansible-lint`).
