terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}
# 💡 테라폼이 스스로 32자리의 무작위 비밀번호를 만듭니다.
resource "random_password" "tunnel_secrets" {
  for_each = toset(["gcp", "aws", "monitoring"])
  length   = 32
  special  = false # 특수문자가 섞이면 간혹 인코딩 문제가 생기므로 false 권장
}

# -------------------------------------------------------------------
# 0. Tunnel 생성 (다른 리소스들이 참조하므로 가장 먼저 정의)
# -------------------------------------------------------------------
resource "cloudflare_zero_trust_tunnel_cloudflared" "tunnels" {
  for_each   = toset(["gcp", "aws", "monitoring"])
  account_id = var.cf_account_id
  name       = "${var.project_name}-${each.key}-tunnel"
  
  # 💡 var.cf_tunnel_secret 대신 랜덤 생성된 값을 사용!
  secret     = base64encode(random_password.tunnel_secrets[each.key].result)
}
# -------------------------------------------------------------------
# 1. Monitor 설정 (v4: header는 '블록' 형태여야 함)
# -------------------------------------------------------------------
resource "cloudflare_load_balancer_monitor" "monitor" {
  account_id     = var.cf_account_id
  type           = "http"
  path           = "/"
  port           = 80
  interval       = 60
  retries        = 2
  expected_codes = "200"

  # 💡 수정: '='를 빼고 대괄호 없이 중괄호 블록으로 작성
  header {
    header = "Host"
    values = [var.app_domain]
  }
}

# -------------------------------------------------------------------
# 2. Pool 설정 (v4: origins는 '속성' 형태)
# -------------------------------------------------------------------
# -------------------------------------------------------------------
# 2. Pool 설정 (v4: origins는 '=' 없이 '블록' 형태로 작성)
# -------------------------------------------------------------------
resource "cloudflare_load_balancer_pool" "pools" {
  for_each   = toset(["gcp", "aws"])
  account_id = var.cf_account_id
  name       = "${var.project_name}-${each.key}-pool"
  monitor    = cloudflare_load_balancer_monitor.monitor.id

  # 💡 수정: 'origins = [{ ... }]' 가 아니라 'origins { ... }' 형태여야 함
  origins {
    name    = "${each.key}-origin"
    address = "${cloudflare_zero_trust_tunnel_cloudflared.tunnels[each.key].id}.cfargotunnel.com"
  }
}
# -------------------------------------------------------------------
# 3. Load Balancer 설정 (v4: 속성명에 _ids 필수)
# -------------------------------------------------------------------
resource "cloudflare_load_balancer" "lb" {
  zone_id = var.cf_zone_id
  name    = var.app_domain
  
  # 💡 수정: v4 표준인 default_pool_ids와 fallback_pool_id 사용
  default_pool_ids = [
    cloudflare_load_balancer_pool.pools["gcp"].id,
    cloudflare_load_balancer_pool.pools["aws"].id
  ]
  fallback_pool_id = cloudflare_load_balancer_pool.pools["aws"].id
  
  proxied = true
}

# -------------------------------------------------------------------
# 4. Tunnel Config 설정 (v4: 최신 리소스명 및 블록 형태)
# -------------------------------------------------------------------
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "configs" {
  for_each   = cloudflare_zero_trust_tunnel_cloudflared.tunnels
  account_id = var.cf_account_id
  tunnel_id  = each.value.id

  config {
    # 💡 수정: ingress_rule { } 중첩 블록 형태
    ingress_rule {
      hostname = each.key == "monitoring" ? var.monitoring_domain : var.app_domain
      service  = "http://localhost:80"
    }
    
    ingress_rule {
      service = "http_status:404"
    }
  }
}