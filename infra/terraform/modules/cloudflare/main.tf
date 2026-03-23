# -------------------------------------------------------------------
# 1. Monitor 설정 (v4: header는 Attribute 형태)
# -------------------------------------------------------------------
resource "cloudflare_load_balancer_monitor" "monitor" {
  account_id     = var.cf_account_id
  type           = "http"
  path           = "/"
  port           = 80
  interval       = 60
  retries        = 2
  expected_codes = "200"

  header = [{
    header = "Host"
    values = [var.app_domain] # 💡 https:// 가 제거된 도메인이어야 함
  }]
}

# -------------------------------------------------------------------
# 2. Pool 설정 (v4: origins는 Attribute 형태)
# -------------------------------------------------------------------
resource "cloudflare_load_balancer_pool" "pools" {
  for_each   = toset(["gcp", "aws"])
  account_id = var.cf_account_id
  name       = "${var.project_name}-${each.key}-pool"
  monitor    = cloudflare_load_balancer_monitor.monitor.id

  origins = [{
    name    = "${each.key}-origin"
    address = "${cloudflare_zero_trust_tunnel_cloudflared.tunnels[each.key].id}.cfargotunnel.com"
  }]
}

# -------------------------------------------------------------------
# 3. Load Balancer 설정
# -------------------------------------------------------------------
resource "cloudflare_load_balancer" "lb" {
  zone_id = var.cf_zone_id
  name    = var.app_domain
  
  default_pool_ids = [
    cloudflare_load_balancer_pool.pools["gcp"].id,
    cloudflare_load_balancer_pool.pools["aws"].id
  ]
  fallback_pool_id = cloudflare_load_balancer_pool.pools["aws"].id
  proxied          = true
}

# -------------------------------------------------------------------
# 4. Tunnel Config 설정 (v4: ingress_rule은 Block 형태)
# -------------------------------------------------------------------
resource "cloudflare_tunnel_config" "configs" {
  for_each   = cloudflare_zero_trust_tunnel_cloudflared.tunnels
  account_id = var.cf_account_id
  tunnel_id  = each.value.id

  config {
    # 💡 수정: '=' 를 빼고 중첩 블록 형태로 작성해야 합니다.
    ingress_rule {
      hostname = each.key == "monitoring" ? var.monitoring_domain : var.app_domain
      service  = "http://localhost:80"
    }
    
    ingress_rule {
      service = "http_status:404"
    }
  }
}