resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    # 1. GCP 
    gcp_ip         = module.gcp.k3s_ephemeral_ip
    gcp_token      = module.cloudflare.gcp_tunnel_token
    db_connection  = module.gcp.db_instance_connection_name

    # 2. AWS 
    aws_ip         = module.aws.k3s_private_ip
    mon_ip         = module.aws.monitoring_private_ip
    bastion_ip     = module.aws.bastion_public_ip
    aws_token      = module.cloudflare.aws_tunnel_token
    mon_token      = module.cloudflare.monitoring_tunnel_token
    cf_id     = module.cloudflare.cf_access_client_id
    cf_secret = module.cloudflare.cf_access_client_secret


    # 3. 기타
    gcp_project_id = var.gcp_project_id
  })

  filename = "${path.module}/../ansible/inventory.ini"
}