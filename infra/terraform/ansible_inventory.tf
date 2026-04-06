# ==============================================================================
# [ansible_inventory.tf]
# ==============================================================================

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    # 1. GCP
    gcp_project_id  = var.gcp_project_id
    gcp_ip          = module.gcp.k3s_ephemeral_ip
    gcp_internal_ip = module.gcp.k3s_internal_ip
    gcp_token       = module.cloudflare.gcp_tunnel_token
    db_connection   = module.gcp.db_instance_connection_name

    # 2. GCP Monitoring
    gcp_mon_ip = module.gcp.monitoring_ephemeral_ip
    mon_token  = module.cloudflare.monitoring_tunnel_token

    # 3. AWS
    aws_ip     = module.aws.k3s_private_ip
    bastion_ip = module.aws.bastion_public_ip
    aws_token  = module.cloudflare.aws_tunnel_token

    # 4. 기타
    cf_id             = module.cloudflare.cf_access_client_id
    cf_secret         = module.cloudflare.cf_access_client_secret
    app_domain        = var.app_domain
    grafana_domain    = var.grafana_domain
    prometheus_domain = var.prometheus_domain
  })

  filename = "${path.module}/../ansible/inventory.ini"
}