terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# 💡 32자리의 무작위 터널 비밀번호 생성
resource "random_password" "tunnel_secrets" {
  for_each = toset(["gcp", "aws", "monitoring"])
  length   = 32
  special  = false
}

# -------------------------------------------------------------------
# 0. Tunnel 생성
# -------------------------------------------------------------------
resource "cloudflare_zero_trust_tunnel_cloudflared" "tunnels" {
  for_each   = toset(["gcp", "aws", "monitoring"])
  account_id = var.cf_account_id
  name       = "${var.project_name}-${each.key}-tunnel"
  secret     = base64encode(random_password.tunnel_secrets[each.key].result)
}

# -------------------------------------------------------------------
# 1. Access 설정 (출입증 및 성문)
# -------------------------------------------------------------------

# 💡 수정: 최신 리소스명 사용 (Deprecated 해결)
resource "cloudflare_zero_trust_access_service_token" "monitoring_token" {
  account_id = var.cf_account_id
  name       = "Chilseongpa-Monitoring-Token"
}

# -------------------------------------------------------------------
# 1. Access 설정 (최신 v4 규격 적용)
# -------------------------------------------------------------------

# 💡 수정: cloudflare_access_application -> cloudflare_zero_trust_access_application
resource "cloudflare_zero_trust_access_application" "gcp_metrics" {
  zone_id = var.cf_zone_id
  name    = "GCP K3s Metrics"
  domain  = "gcp-metrics.${var.app_domain}"
  type    = "self_hosted"
}

# 💡 수정: cloudflare_access_policy -> cloudflare_zero_trust_access_policy
resource "cloudflare_zero_trust_access_policy" "gcp_metrics_policy" {
  application_id = cloudflare_zero_trust_access_application.gcp_metrics.id
  zone_id        = var.cf_zone_id
  name           = "Allow Prometheus Scraper"
  
  # 💡 중요: "service_auth" 대신 "non_identity"를 사용해야 합니다.
  # 서비스 토큰을 통한 인증은 '사용자 ID'가 없는 방식이기 때문입니다.
  decision       = "non_identity" 
  precedence     = 1

  include {
    service_token = [cloudflare_zero_trust_access_service_token.monitoring_token.id]
  }
}
# -------------------------------------------------------------------
# 2. Tunnel Config 설정 (포트 수정 반영)
# -------------------------------------------------------------------
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "configs" {
  for_each   = cloudflare_zero_trust_tunnel_cloudflared.tunnels
  account_id = var.cf_account_id
  tunnel_id  = each.value.id

  config {
    ingress_rule {
      hostname = each.key == "monitoring" ? var.monitoring_domain : var.app_domain
      # 💡 수정: 모니터링 서버는 80이 아닌 3000번 포트(Grafana)를 바라봐야 합니다.
      service  = each.key == "monitoring" ? "http://localhost:3000" : "http://localhost:80"
    }

    dynamic "ingress_rule" {
      for_each = each.key == "gcp" ? [1] : []
      content {
        hostname = "gcp-metrics.${var.app_domain}"
        service  = "http://localhost:9100" 
      }
    }
    
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# -------------------------------------------------------------------
# 4. DNS 레코드 추가 (누락되었던 부분)
# -------------------------------------------------------------------
# 💡 터널 도메인과 실제 주소를 연결하는 CNAME 레코드가 반드시 필요합니다.
resource "cloudflare_record" "status_record" {
  zone_id = var.cf_zone_id
  name    = "status" # status.bucheongoyangijanggun.com
  content   = "${cloudflare_zero_trust_tunnel_cloudflared.tunnels["monitoring"].id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "metrics_record" {
  zone_id = var.cf_zone_id
  name    = "gcp-metrics"
  content   = "${cloudflare_zero_trust_tunnel_cloudflared.tunnels["gcp"].id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

# -------------------------------------------------------------------
# 3. Load Balancer & 기타 (기존 코드 유지)
# -------------------------------------------------------------------
resource "cloudflare_load_balancer_monitor" "monitor" {
  account_id     = var.cf_account_id
  type           = "http"
  path           = "/"
  port           = 80
  interval       = 60
  retries        = 2
  expected_codes = "200"

  header {
    header = "Host"
    values = [var.app_domain]
  }
}

resource "cloudflare_load_balancer_pool" "pools" {
  for_each   = toset(["gcp", "aws"])
  account_id = var.cf_account_id
  name       = "${var.project_name}-${each.key}-pool"
  monitor    = cloudflare_load_balancer_monitor.monitor.id

  origins {
    name    = "${each.key}-origin"
    address = "${cloudflare_zero_trust_tunnel_cloudflared.tunnels[each.key].id}.cfargotunnel.com"
  }
}

resource "cloudflare_load_balancer" "lb" {
  zone_id = var.cf_zone_id
  name    = var.app_domain
  
  default_pool_ids = [
    cloudflare_load_balancer_pool.pools["gcp"].id,
    cloudflare_load_balancer_pool.pools["aws"].id
  ]
  fallback_pool_id = cloudflare_load_balancer_pool.pools["aws"].id
  proxied = true
}