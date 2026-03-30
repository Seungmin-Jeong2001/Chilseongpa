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

resource "cloudflare_zero_trust_access_policy" "gcp_metrics_policy" {
  application_id = cloudflare_zero_trust_access_application.gcp_metrics.id
  zone_id        = var.cf_zone_id
  name           = "Allow Prometheus Scraper"
  decision       = "non_identity"
  precedence     = 1

  include {
    service_token = [cloudflare_zero_trust_access_service_token.monitoring_token.id]
  }
}

resource "cloudflare_zero_trust_access_application" "gcp_app_metrics" {
  zone_id = var.cf_zone_id
  name    = "GCP App Metrics"
  domain  = "gcp-app-metrics.${var.app_domain}"
  type    = "self_hosted"
}

resource "cloudflare_zero_trust_access_policy" "gcp_app_metrics_policy" {
  application_id = cloudflare_zero_trust_access_application.gcp_app_metrics.id
  zone_id        = var.cf_zone_id
  name           = "Allow Prometheus Scraper"
  decision       = "non_identity"
  precedence     = 1

  include {
    service_token = [cloudflare_zero_trust_access_service_token.monitoring_token.id]
  }
}

resource "cloudflare_zero_trust_access_application" "gcp_kube_state" {
  zone_id = var.cf_zone_id
  name    = "GCP kube-state-metrics"
  domain  = "gcp-kube-state.${var.app_domain}"
  type    = "self_hosted"
}

resource "cloudflare_zero_trust_access_policy" "gcp_kube_state_policy" {
  application_id = cloudflare_zero_trust_access_application.gcp_kube_state.id
  zone_id        = var.cf_zone_id
  name           = "Allow Prometheus Scraper"
  decision       = "non_identity"
  precedence     = 1

  include {
    service_token = [cloudflare_zero_trust_access_service_token.monitoring_token.id]
  }
}
# -------------------------------------------------------------------
# 2. Tunnel Config 설정 (인바운드 규칙)
# -------------------------------------------------------------------
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "configs" {
  for_each   = cloudflare_zero_trust_tunnel_cloudflared.tunnels
  account_id = var.cf_account_id
  tunnel_id  = each.value.id

  config {
    # 서비스별 도메인 접속 규칙
    ingress_rule {
      hostname = each.key == "monitoring" ? var.monitoring_domain : var.app_domain
      service  = "http://localhost:80"
    }

    # 💡 GCP 터널: Node Exporter (9100) 수집
    dynamic "ingress_rule" {
      for_each = each.key == "gcp" ? [1] : []
      content {
        hostname = "gcp-metrics.${var.app_domain}"
        service  = "http://localhost:9100"
      }
    }

    # 💡 GCP 터널: App /metrics (8000) 수집
    dynamic "ingress_rule" {
      for_each = each.key == "gcp" ? [1] : []
      content {
        hostname = "gcp-app-metrics.${var.app_domain}"
        service  = "http://localhost:8000"
      }
    }

    # 💡 GCP 터널: kube-state-metrics (NodePort 30080) 수집
    dynamic "ingress_rule" {
      for_each = each.key == "gcp" ? [1] : []
      content {
        hostname = "gcp-kube-state.${var.app_domain}"
        service  = "http://localhost:30080"
      }
    }
    
    ingress_rule {
      service = "http_status:404"
    }
  }
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