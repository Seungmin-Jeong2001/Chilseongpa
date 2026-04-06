terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# -------------------------------------------------------------------
# 0. Tunnel 생성 및 비밀번호 자동 관리
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
# 1. Access 설정 (인증 및 Bypass 정책)
# -------------------------------------------------------------------
resource "cloudflare_zero_trust_access_service_token" "monitoring_token" {
  account_id = var.cf_account_id
  name       = "Chilseongpa-Monitoring-Token"
}

# 일반 모니터링 앱 (Prometheus 스크래핑용)
resource "cloudflare_zero_trust_access_application" "apps" {
  for_each = toset([
    "gcp-metrics", "gcp-app", "gcp-ksm",
    "aws-node", "aws-app", "aws-ksm"
  ])
  zone_id = var.cf_zone_id
  name    = "Monitoring-${each.key}"
  domain  = "${each.key}.bucheongoyangijanggun.com"
  type    = "self_hosted"
}

# AWS K8s API 전용 앱 (Bypass 대상)
resource "cloudflare_zero_trust_access_application" "aws_k8s_api" {
  zone_id = var.cf_zone_id
  name    = "AWS-K8s-API-Access"
  domain  = "aws-k8s.bucheongoyangijanggun.com"
  type    = "self_hosted"
}

# 일반 앱용 정책: 서비스 토큰 인증
resource "cloudflare_zero_trust_access_policy" "monitoring_policy" {
  for_each       = cloudflare_zero_trust_access_application.apps
  application_id = each.value.id
  zone_id         = var.cf_zone_id
  name           = "Allow Prometheus Scraper"
  decision       = "non_identity"
  precedence     = 1

  include {
    service_token = [cloudflare_zero_trust_access_service_token.monitoring_token.id]
  }
}

# K8s API용 정책: Bypass
resource "cloudflare_zero_trust_access_policy" "aws_k8s_bypass_policy" {
  application_id = cloudflare_zero_trust_access_application.aws_k8s_api.id
  zone_id         = var.cf_zone_id
  name           = "Bypass for K8s API Auth"
  decision       = "bypass"
  precedence     = 1

  include {
    everyone = true
  }
}

# -------------------------------------------------------------------
# 2. Tunnel Config (봇 웹훅 경로 추가됨)
# -------------------------------------------------------------------
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "configs" {
  for_each   = cloudflare_zero_trust_tunnel_cloudflared.tunnels
  account_id = var.cf_account_id
  tunnel_id  = each.value.id

  config {
    # Monitoring 터널 (Grafana/Prometheus/Bot Webhook)
    dynamic "ingress_rule" {
      for_each = each.key == "monitoring" ? [1] : []
      content {
        hostname = var.grafana_domain
        service  = "http://localhost:3000"
      }
    }
    dynamic "ingress_rule" {
      for_each = each.key == "monitoring" ? [1] : []
      content {
        hostname = var.prometheus_domain
        service  = "http://localhost:9090"
      }
    }
    # 💡 [추가] 봇 API용 인그레스 규칙
    dynamic "ingress_rule" {
      for_each = each.key == "monitoring" ? [1] : []
      content {
        hostname = "bot-webhook.bucheongoyangijanggun.com"
        service  = "http://localhost:5000"
      }
    }

    # GCP 터널
    dynamic "ingress_rule" {
      for_each = each.key == "gcp" ? [1] : []
      content {
        hostname = "gcp-metrics.bucheongoyangijanggun.com"
        service  = "http://localhost:9100"
      }
    }
    dynamic "ingress_rule" {
      for_each = each.key == "gcp" ? [1] : []
      content {
        hostname = "gcp-app.bucheongoyangijanggun.com"
        service  = "http://localhost:80"
      }
    }
    dynamic "ingress_rule" {
      for_each = each.key == "gcp" ? [1] : []
      content {
        hostname = "gcp-ksm.bucheongoyangijanggun.com"
        service  = "http://localhost:80"
      }
    }

    # AWS 터널
    dynamic "ingress_rule" {
      for_each = each.key == "aws" ? [1] : []
      content {
        hostname = "aws-node.bucheongoyangijanggun.com"
        service  = "http://localhost:9100"
      }
    }
    dynamic "ingress_rule" {
      for_each = each.key == "aws" ? [1] : []
      content {
        hostname = "aws-app.bucheongoyangijanggun.com"
        service  = "http://localhost:30800"
      }
    }
    dynamic "ingress_rule" {
      for_each = each.key == "aws" ? [1] : []
      content {
        hostname = "aws-ksm.bucheongoyangijanggun.com"
        service  = "http://localhost:30080" 
      }
    }
    dynamic "ingress_rule" {
      for_each = each.key == "aws" ? [1] : []
      content {
        hostname = "aws-k8s.bucheongoyangijanggun.com"
        service  = "https://localhost:6443"
        origin_request {
          no_tls_verify = true
        }
      }
    }

    # 공통 앱 배포 규칙
    ingress_rule {
      hostname = var.app_domain
      service  = "http://localhost:80"
    }

    ingress_rule {
      service = "http_status:404"
    }
  }
}

# -------------------------------------------------------------------
# 3. DNS 레코드 설정 (봇 웹훅 레코드 추가됨)
# -------------------------------------------------------------------
resource "cloudflare_record" "records" {
  for_each = {
    grafana     = { name = "grafana", tunnel = "monitoring" }
    prometheus  = { name = "prometheus", tunnel = "monitoring" }
    bot-webhook = { name = "bot-webhook", tunnel = "monitoring" } # 💡 [추가]
    gcp-metrics = { name = "gcp-metrics", tunnel = "gcp" }
    gcp-app      = { name = "gcp-app", tunnel = "gcp" }
    gcp-ksm      = { name = "gcp-ksm", tunnel = "gcp" }
    aws-node     = { name = "aws-node", tunnel = "aws" }
    aws-app      = { name = "aws-app", tunnel = "aws" }
    aws-ksm      = { name = "aws-ksm", tunnel = "aws" }
    aws-k8s      = { name = "aws-k8s", tunnel = "aws" }
  }
  zone_id = var.cf_zone_id
  name    = each.value.name
  content = "${cloudflare_zero_trust_tunnel_cloudflared.tunnels[each.value.tunnel].id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

# -------------------------------------------------------------------
# 4. Load Balancer 설정
# -------------------------------------------------------------------
resource "cloudflare_load_balancer_monitor" "monitor" {
  account_id     = var.cf_account_id
  type           = "http"
  path           = "/health"
  port           = 80
  interval       = 60
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

# -------------------------------------------------------------------
# 5. [추가] 알림 정책 (Cloudflare LB -> Bot Webhook)
# -------------------------------------------------------------------
resource "cloudflare_notification_policy_webhooks" "bot_webhook" {
  account_id = var.cf_account_id
  name       = "Chilseongpa-Bot-Webhook"
  # 봇 코드의 @app.route('/cloudflare-alert')와 일치
  url        = "https://bot-webhook.bucheongoyangijanggun.com/cloudflare-alert"
}

resource "cloudflare_notification_policy" "lb_health_alert" {
  account_id  = var.cf_account_id
  name        = "LB Pool Health Alert"
  description = "LB 풀 상태 변화 시 봇으로 알림 전송"
  enabled     = true
  alert_type  = "load_balancing_health_status"

  webhooks_integration_ids = [cloudflare_notification_policy_webhooks.bot_webhook.id]

  filters {
    pool_id    = [for p in cloudflare_load_balancer_pool.pools : p.id]
    new_health = ["Unhealthy", "Healthy"]
  }
}