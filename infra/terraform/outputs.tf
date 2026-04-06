# ==============================================================================
# [outputs.tf]
# ==============================================================================


# -----------------------------------------------
# Ansible Inventory Data (For GitHub Actions)
# -----------------------------------------------
output "ansible_inventory_data" {
  description = "Inventory data for GitHub Actions to generate inventory.ini dynamically"
  sensitive   = true
  value = {
    gcp_ip            = module.gcp.k3s_ephemeral_ip
    gcp_internal_ip   = module.gcp.k3s_internal_ip
    gcp_mon_ip        = module.gcp.monitoring_ephemeral_ip
    aws_ip            = module.aws.k3s_public_ip
    gcp_token         = module.cloudflare.gcp_tunnel_token
    mon_token         = module.cloudflare.monitoring_tunnel_token
    aws_token         = module.cloudflare.aws_tunnel_token
    db_connection     = module.gcp.db_instance_connection_name
    cf_id             = module.cloudflare.cf_access_client_id
    cf_secret         = module.cloudflare.cf_access_client_secret
    app_domain        = var.app_domain
    grafana_domain    = var.grafana_domain
    prometheus_domain = var.prometheus_domain
    gcp_project_id    = var.gcp_project_id
    cf_webhook_id     = module.cloudflare.cf_webhook_id
  }
}

output "cloudflare_webhook_id" {
  value = module.cloudflare.cf_webhook_id
}

# -----------------------------------------------
# GCP Primary outputs
# -----------------------------------------------
output "gcp_k3s_ephemeral_ip" {
  description = "GCP K3s 임시 공인 IP (Ansible 초기 접속용)"
  value       = module.gcp.k3s_ephemeral_ip
}

output "gcp_db_proxy_sa_key" {
  description = "AWS DB 연동을 위한 Cloud SQL Proxy JSON 키"
  value       = module.gcp.db_proxy_sa_key
  sensitive   = true
}

# -----------------------------------------------
# GCP Monitoring Server outputs
# -----------------------------------------------
output "gcp_monitoring_ephemeral_ip" {
  description = "GCP Monitoring Server Public IP (Ansible 접속용)"
  value       = module.gcp.monitoring_ephemeral_ip
}


# -----------------------------------------------
# AWS Network outputs
# -----------------------------------------------
output "aws_vpc_id" {
  description = "AWS VPC ID"
  value       = module.aws.vpc_id
}

output "aws_public_subnet_id" {
  description = "AWS Public Subnet ID"
  value       = module.aws.public_subnet_id
}

# -----------------------------------------------
# AWS k3s node outputs
# -----------------------------------------------
output "aws_k3s_public_ip" {
  description = "AWS k3s Node Public IP"
  value       = module.aws.k3s_public_ip
}

output "aws_standby_security_group_id" {
  description = "AWS k3s 노드 Security Group ID"
  value       = module.aws.standby_security_group_id
}
