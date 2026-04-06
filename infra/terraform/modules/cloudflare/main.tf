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
# 1. Access 설정
# -------------------------------------------------------------------
resource "cloudflare_zero_trust_access_service_token" "monitoring_token" {
  account_id = var.cf_account_id
  name       = "Chilseongpa-Monitoring-Token"
}

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

resource "cloudflare_zero_trust_access_application" "aws_k8s_api" {
  zone_id = var.cf_zone_id
  name    = "AWS-K8s-API-Access"
  domain  = "aws-k8s.bucheongoyangijanggun.com"
  type    = "self_hosted"
}

resource "cloudflare_zero_trust_access_policy" "monitoring_policy" {
  for_each       = cloudflare_zero_trust_access_application.apps
  application_id = each.value.id
  # 앱이 zone_id를 쓰므로 정책도 zone_id를 써야 합니다.
  zone_id        = var.cf_zone_id
  name           = "Allow Prometheus Scraper"
  decision       = "non_identity"
  precedence     = 1

  include {
    # ✅ 수정: 단일 ID 문자열 리스트로 변경
    service_token = [cloudflare_zero_trust_access_service_token.monitoring_token.id]
  }
}

resource "cloudflare_zero_trust_access_policy" "aws_k8s_bypass_policy" {
  application_id = cloudflare_zero_trust_access_application.aws_k8s_api.id
  zone_id        = var.cf_zone_id
  name           = "Bypass for K8s API Auth"
  decision       = "bypass"
  precedence     = 1

  include {
    everyone = true
  }
}

# -------------------------------------------------------------------
# 2. Tunnel Config
# -------------------------------------------------------------------
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "configs" {
  for_each   = cloudflare_zero_trust_tunnel_cloudflared.tunnels
  account_id = var.cf_account_id
  tunnel_id  = each.value.id

  config {
    # Monitoring
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

    dynamic "ingress_rule" {
      for_each = each.key == "monitoring" ? [1] : []
      content {
        hostname = "bot-webhook.bucheongoyangijanggun.com"
        service  = "http://localhost:5000"
      }
    }

    # GCP
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

    # AWS
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
          no_tls_verify      = true
          origin_server_name = "aws-k8s.bucheongoyangijanggun.com"
        }
      }
    }

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
# 3. DNS
# -------------------------------------------------------------------
resource "cloudflare_record" "records" {
  for_each = {
    grafana     = { name = "grafana", tunnel = "monitoring" }
    prometheus  = { name = "prometheus", tunnel = "monitoring" }
    bot-webhook = { name = "bot-webhook", tunnel = "monitoring" }
    gcp-metrics = { name = "gcp-metrics", tunnel = "gcp" }
    gcp-app     = { name = "gcp-app", tunnel = "gcp" }
    gcp-ksm     = { name = "gcp-ksm", tunnel = "gcp" }
    aws-node    = { name = "aws-node", tunnel = "aws" }
    aws-app     = { name = "aws-app", tunnel = "aws" }
    aws-ksm     = { name = "aws-ksm", tunnel = "aws" }
    aws-k8s     = { name = "aws-k8s", tunnel = "aws" }
  }

  zone_id = var.cf_zone_id
  name    = each.value.name
  content = "${cloudflare_zero_trust_tunnel_cloudflared.tunnels[each.value.tunnel].id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

# -------------------------------------------------------------------
# 4. Load Balancer
# -------------------------------------------------------------------
resource "cloudflare_load_balancer_monitor" "monitor" {
  account_id     = var.cf_account_id
  type           = "http"
  path           = "/health"
  port           = 80
  interval       = 60
  expected_codes = "200"

  # ✅ 수정: v4에서는 name 대신 header 키를 사용합니다.
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
  proxied          = true
}

# -------------------------------------------------------------------
# 5. Notification (Webhook)
# -------------------------------------------------------------------
# ✅ 수정: 리소스 이름 'cloudflare_notification_policy_webhooks'
resource "cloudflare_notification_policy_webhooks" "bot_webhook" {
  account_id = var.cf_account_id
  name       = "Chilseongpa-Bot-Webhook"
  url        = "https://bot-webhook.bucheongoyangijanggun.com/cloudflare-alert"
}

resource "cloudflare_notification_policy" "lb_health_alert" {
  account_id  = var.cf_account_id
  name        = "LB Pool Health Alert"
  description = "LB 풀 상태 변화 시 봇으로 알림 전송"
  enabled     = true
  # ✅ 수정: 정확한 알림 타입 지정
  alert_type  = "load_balancing_health_alert"

  # ✅ 수정: 속성(id) 대신 블록(block) 형태로 작성해야 합니다.
  webhooks_integration {
    id = cloudflare_notification_policy_webhooks.bot_webhook.id
  }

  filters {
    pool_id    = [for p in cloudflare_load_balancer_pool.pools : p.id]
    new_health = ["Unhealthy", "Healthy"]
  }
}