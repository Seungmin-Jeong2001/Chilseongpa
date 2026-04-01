terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# -------------------------------------------------------------------
# 0. Tunnel 생성 및 비밀번호 관리
# -------------------------------------------------------------------
resource "random_password" "tunnel_secrets" {
  for_each = toset(["gcp", "aws", "monitoring"])
  length   = 32
  special  = false
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "tunnels" {
  for_each   = toset(["gcp", "aws", "monitoring"])
  account_id = var.cf_account_id
  name       = "${var.project_name}-${each.key}-tunnel"
  secret     = base64encode(random_password.tunnel_secrets[each.key].result)
}

# -------------------------------------------------------------------
# 1. Access 설정 (인증 및 토큰)
# -------------------------------------------------------------------
resource "cloudflare_zero_trust_access_service_token" "monitoring_token" {
  account_id = var.cf_account_id
  name       = "Chilseongpa-Monitoring-Token"
}

resource "cloudflare_zero_trust_access_application" "gcp_metrics" {
  zone_id = var.cf_zone_id
  name    = "GCP K3s Metrics"
  domain  = "gcp-metrics.bucheongoyangijanggun.com"
  type    = "self_hosted"
}

resource "cloudflare_zero_trust_access_policy" "gcp_metrics_policy" {
  application_id = cloudflare_zero_trust_access_application.gcp_metrics.id
  zone_id         = var.cf_zone_id
  name           = "Allow Prometheus Scraper"
  decision       = "non_identity"
  precedence     = 1

  include {
    service_token = [cloudflare_zero_trust_access_service_token.monitoring_token.id]
  }
}

# [추가] GCP 앱 메트릭(8000) 수집을 위한 Zero Trust 보호
# 기존 gcp-metrics(9100, node exporter)만으로는 HTTP 요청수/응답시간 수집 불가
resource "cloudflare_zero_trust_access_application" "gcp_app" {
  zone_id = var.cf_zone_id
  name    = "GCP K3s App Metrics"
  domain  = "gcp-app.bucheongoyangijanggun.com"
  type    = "self_hosted"
}

resource "cloudflare_zero_trust_access_policy" "gcp_app_policy" {
  application_id = cloudflare_zero_trust_access_application.gcp_app.id
  zone_id        = var.cf_zone_id
  name           = "Allow Prometheus Scraper"
  decision       = "non_identity"
  precedence     = 1

  include {
    # 기존 monitoring_token 재사용
    service_token = [cloudflare_zero_trust_access_service_token.monitoring_token.id]
  }
}

# [추가] GCP kube-state-metrics(30080) 수집을 위한 Zero Trust 보호
# GCP(Primary)/AWS 모두 Pod/Container 상태 모니터링 필요
resource "cloudflare_zero_trust_access_application" "gcp_ksm" {
  zone_id = var.cf_zone_id
  name    = "GCP K3s kube-state-metrics"
  domain  = "gcp-ksm.bucheongoyangijanggun.com"
  type    = "self_hosted"
}

resource "cloudflare_zero_trust_access_policy" "gcp_ksm_policy" {
  application_id = cloudflare_zero_trust_access_application.gcp_ksm.id
  zone_id        = var.cf_zone_id
  name           = "Allow Prometheus Scraper"
  decision       = "non_identity"
  precedence     = 1

  include {
    # 기존 monitoring_token 재사용
    service_token = [cloudflare_zero_trust_access_service_token.monitoring_token.id]
  }
}

# -------------------------------------------------------------------
# 2. Tunnel Config 설정 (멀티 서비스 매핑)
# -------------------------------------------------------------------
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "configs" {
  for_each   = cloudflare_zero_trust_tunnel_cloudflared.tunnels
  account_id = var.cf_account_id
  tunnel_id  = each.value.id

  config {
    # [A] Monitoring 터널 전용 규칙 (Grafana & Prometheus)
    dynamic "ingress_rule" {
      for_each = each.key == "monitoring" ? [1] : []
      content {
        hostname = var.grafana_domain # monitoring.bucheong...
        service  = "http://localhost:3000" # Grafana 접속
      }
    }

    dynamic "ingress_rule" {
      for_each = each.key == "monitoring" ? [1] : []
      content {
        hostname = var.prometheus_domain
        service  = "http://localhost:9090" # Prometheus 접속
      }
    }

    # [B] GCP 터널 전용 규칙 (Node Exporter / App Metrics / kube-state-metrics)
    dynamic "ingress_rule" {
      for_each = each.key == "gcp" ? [1] : []
      content {
        hostname = "gcp-metrics.bucheongoyangijanggun.com"
        service  = "http://localhost:9100" # node exporter - CPU/Memory
      }
    }

    # [추가] GCP 앱 메트릭 수집 - HTTP 요청수/응답시간
    dynamic "ingress_rule" {
      for_each = each.key == "gcp" ? [1] : []
      content {
        hostname = "gcp-app.bucheongoyangijanggun.com"
        service  = "http://localhost:8000"
      }
    }

    # [추가] GCP kube-state-metrics 수집 - GCP(Primary)/AWS(Fallback) Pod/Container 상태 모니터링
    dynamic "ingress_rule" {
      for_each = each.key == "gcp" ? [1] : []
      content {
        hostname = "gcp-ksm.bucheongoyangijanggun.com"
        service  = "http://localhost:30080"
      }
    }

    # [C] 기본 공통 규칙 (App 배포용)
    ingress_rule {
      hostname = var.app_domain # app.bucheong...
      service  = "http://localhost:80"
    }

    # [D] Catch-all 규칙 (필수)
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# -------------------------------------------------------------------
# 3. DNS 레코드 설정 (도메인 - 터널 연결)
# -------------------------------------------------------------------
# Grafana 도메인
resource "cloudflare_record" "monitoring_record" {
  zone_id = var.cf_zone_id
  name    = "grafana"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.tunnels["monitoring"].id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

# Prometheus 도메인
resource "cloudflare_record" "prometheus_record" {
  zone_id = var.cf_zone_id
  name    = "prometheus"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.tunnels["monitoring"].id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

# GCP Metrics 도메인 (node exporter - CPU/Memory)
resource "cloudflare_record" "metrics_record" {
  zone_id = var.cf_zone_id
  name    = "gcp-metrics"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.tunnels["gcp"].id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

# [추가] GCP App 메트릭 도메인 (포트 8000 - HTTP 요청수/응답시간)
resource "cloudflare_record" "gcp_app_record" {
  zone_id = var.cf_zone_id
  name    = "gcp-app"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.tunnels["gcp"].id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

# [추가] GCP kube-state-metrics 도메인 (포트 8080 - Pod/Container 상태)
resource "cloudflare_record" "gcp_ksm_record" {
  zone_id = var.cf_zone_id
  name    = "gcp-ksm"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.tunnels["gcp"].id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

# -------------------------------------------------------------------
# 4. Load Balancer 설정
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