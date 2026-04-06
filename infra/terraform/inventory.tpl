# ==============================================================================
# [inventory.tpl]
# ==============================================================================

[gcp_k3s]
gcp-k3s ansible_host=${gcp_ip}

[gcp_monitoring]
gcp-monitoring ansible_host=${gcp_mon_ip}

[aws_k3s]
aws-k3s ansible_host=${aws_ip}

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=../../chilseongpa_keypair.pem
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
