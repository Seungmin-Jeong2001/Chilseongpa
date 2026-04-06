# ==============================================================================
# [ansible_inventory.tf]
# ==============================================================================


# -----------------------------------------------
# Ansible inventory.ini 동적 생성
# -----------------------------------------------
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    gcp_ip     = module.gcp.k3s_ephemeral_ip
    gcp_mon_ip = module.gcp.monitoring_ephemeral_ip
    aws_ip     = module.aws.k3s_public_ip
  })
  filename = "${path.module}/../ansible/inventory.ini"
}
