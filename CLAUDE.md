# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Chilseongpa** is a Hybrid Multi-Cloud AIOps Platform built on GCP (primary) and AWS (standby) with Cloudflare Edge routing for automatic failover. It combines Prometheus-based observability with LLM-based (Gemini API) automated failure analysis via a Discord Bot.

## Architecture

### Active-Standby Hybrid Cloud

```
Client → Cloudflare Edge (Zero Trust Tunnels + Load Balancer)
           ├─→ GCP K3s Cluster (Primary) ─→ Cloud SQL
           └─→ AWS K3s Cluster (Standby)

AWS Monitoring Server (Prometheus + Grafana + Alertmanager)
  └─→ AlertManager → Discord Bot → Gemini API (AIOps analysis)
```

- **GCP** (`asia-northeast3`): Primary K3s cluster, Cloud SQL, e2-standard-2 instance
- **AWS** (`ap-northeast-2`): Standby K3s cluster + Monitoring server, VPC `10.20.0.0/16`
  - Public subnet `10.20.1.0/24`: Bastion, NAT Gateway
  - Private subnet `10.20.2.0/24`: K3s node (t3.small), Monitoring (t3.small, 30GB EBS)
- **Cloudflare**: Zero Trust Tunnels + health-check-based failover between GCP and AWS

### Key Domains

- App: `app.bucheongoyangijanggun.com`
- Monitoring: `status.bucheongoyangijanggun.com`

## Repository Structure

| Path | Purpose |
|------|---------|
| `infra/terraform/` | IaC for GCP, AWS, Cloudflare resources |
| `infra/ansible/` | Server configuration (K3s, Docker, monitoring stack) |
| `application/backend/` | Backend API application |
| `application/k8s/` | Kubernetes manifests |
| `application/k6/` | k6 load testing scenarios |
| `aiops/discord-bot/` | Discord bot for AIOps (Gemini API integration) |
| `platform/cicd/` | CI/CD pipeline configuration |
| `.github/workflows/` | GitHub Actions (PR Discord notifications) |

## Infrastructure Workflow

### Terraform

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # Fill in secrets
terraform init
terraform plan
terraform apply
```

Required variables: `gcp_project_id`, `gcp_credentials`, `gcp_ssh_public_key`, `gcp_db_password`, `cf_api_token`, `cf_account_id`, `cf_zone_id`, `cf_tunnel_secret`

Terraform is organized as modules: `modules/gcp/`, `modules/aws/`, `modules/cloudflare/`

### Ansible

```bash
cd infra/ansible
# Configure hosts in inventory, secrets in group_vars/all.yml
ansible-playbook -i inventory playbooks/k3s.yml        # K3s setup
ansible-playbook -i inventory playbooks/monitoring.yml  # Prometheus + Grafana + Alertmanager
ansible-playbook -i inventory playbooks/node-exporter.yml
```

Inventory groups: `gcp-main`, `aws-sub`, `aws-monitor`

### Kubernetes

```bash
kubectl apply -f application/k8s/
```

### Load Testing

```bash
cd application/k6
k6 run <scenario>.js
```

## Monitoring Stack (deployed via Ansible on AWS monitoring server)

- **Prometheus**: scrapes node metrics + app `/metrics` endpoints
- **Alertmanager**: alert thresholds — Warning: 70%, Critical: 85% (CPU/Memory)
- **Grafana**: auto-provisioned dashboards
- **Discord Bot**: receives Alertmanager webhooks → calls Gemini API for root cause analysis

Alert categories: `resource`, `application`, `network`, `cloud`

## Secrets and Sensitive Files

Never commit: `*.tfvars`, `*.tfstate`, `*.pem`, `*.key`, `*.kubeconfig`, `*.json` (GCP credentials), `.env` files. These are all in `.gitignore`.

The `group_vars/all.yml` in Ansible holds Discord token, Gemini API key, and domain config — do not commit with real values.
