[gcp_primary]
gcp-main ansible_host=${gcp_ip} tunnel_token=${gcp_token} db_conn=${db_connection}

[gcp_monitoring]
gcp-monitor ansible_host=${gcp_mon_ip} tunnel_token=${mon_token}

[aws_bastion]
aws-bastion ansible_host=${bastion_ip}

[aws_nodes]
aws-sub ansible_host=${aws_ip} tunnel_token=${aws_token}

# --- 그룹별 변수 설정 ---

[gcp_primary:vars]
ansible_ssh_private_key_file=../../my_gcp_key

[gcp_monitoring:vars]
ansible_ssh_private_key_file=../../my_gcp_key
storage_setup_enabled=false

[aws_bastion:vars]
ansible_ssh_private_key_file=../../chilseongpa_keypair.pem

[aws_nodes:vars]
ansible_ssh_private_key_file=../../chilseongpa_keypair.pem
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -q ubuntu@${bastion_ip} -i ../../chilseongpa_keypair.pem -o StrictHostKeyChecking=no"'

[all:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_user=ubuntu
gcp_project_id=${gcp_project_id}
cf_client_id=${cf_id}
cf_client_secret=${cf_secret}
aws_ip=${aws_ip}
gcp_ip=${gcp_ip}
gcp_internal_ip=${gcp_internal_ip}
app_domain=${app_domain}
grafana_domain=${grafana_domain}
prometheus_domain=${prometheus_domain}
db_instance_name=${db_connection}
