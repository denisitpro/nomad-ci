job "[[.app_name | replace "-" "_"]]_[[.contour]]_[[.stand_env]]" {
  region = "[[.app.region]]"
  namespace = "[[.app.namespace]]"
  datacenters = ["[[.app.datacenters]]"]
  type = "service"
  update {
    max_parallel = 1
    min_healthy_time = "10s"
    healthy_deadline = "3m"
    progress_deadline = "5m"
    auto_revert = false
    canary = 0
  }
  migrate {
    max_parallel = 1
    health_check = "checks"
    min_healthy_time = "10s"
    healthy_deadline = "5m"
  }
  group "[[.app_name | replace "-" "_"]]_group" {
    count = [[.app.group.count]]
    network {
      port "[[.app_name | replace "-" "_"]]_net" {
        to = [[.app.port]]
      }
      port "metrics_port" {
        to = [[.metrics_port]]
     }
    }
    service {
      name = "[[.app_name | replace "_" "-"]]-[[.contour]]-[[.stand_env]]"
      tags = ["[[.app_name]]", "[[.contour]]-[[.stand_env]]"]
      port = "[[.app_name | replace "-" "_"]]_net"
      check {
        type     = "http"
        protocol = "https"
        port     = "[[.app_name | replace "-" "_"]]_net"
        path     = "/hc"
        interval = "10s"
        timeout  = "2s"
        tls_skip_verify = true
      }
    }
    service {
      name = "[[.app_name | replace "_" "-"]]-metrics-[[.contour]]-[[.stand_env]]"
      tags = ["[[.app_name]]", [[.metrics_prometheus_http_tags]], "[[.contour]]-[[.stand_env]]"]
      port = "metrics_port"
      check {
        type     = "http"
        protocol = "http"
        port     = "metrics_port"
        path     = "[[.metrics_path]]"
        interval = "10s"
        timeout  = "2s"
      }
    }
    restart {
      attempts = 2
      interval = "20s"
      delay = "5s"
      mode = "delay"
    }
    ephemeral_disk {
      size = 300
    }
    task "[[.app_name | replace "-" "_"]]_[[.contour]]_[[.stand_env]]" {
      vault {
        policies = "[[.vault_policies]]"
            }
      driver = "docker"
      config {
        image = "[[.image_registry]]:[[.image_tag]]"
        ports = ["[[.app_name | replace "-" "_"]]_net", "metrics_port"]
        force_pull = true
        dns_servers = ["[[.dns_01]]", "[[.dns_02]]"]
        auth {
          username = "[[.docker_login]]"
          password = "[[.docker_token]]"
        }
        logging {
          type = "fluentd"
          config  {
            fluentd-address = "[[.vector_addr]]"
            tag = "[[.app_tag]]"
                  }
                }
      }
      template {
        destination = "secrets/file.env"
        env         = true
        data        = <<EOF
[[ if .app.vault.dynamic_secret ]]
{{ with secret "[[.app.vault.dynamic_secret]]" }}
MYSQL_USER="{{ .Data.username }}"
MYSQL_PASSWORD="{{ .Data.password }}"
{{ end }}
[[ else ]]
{{ with secret "[[.app.vault.app_mysql_user_pass]]" }}
MYSQL_USER = "[[.app.env.app_mysql_user]]"
MYSQL_PASSWORD="{{ .Data.data.value }}"
{{ end }}
[[ end ]]
{{ with secret "[[.app.vault.app_clickhouse_pass]]" }}
CLICKHOUSE_PASSWORD="{{ .Data.data.value }}"
{{ end }}
{{ with secret "[[.app.vault.consul_internal_apps_read_token]]" }}
CONSUL_TOKEN="{{ .Data.data.value }}"
{{ end }}
EOF
            }
      env {
        NODE_ENV = "production"
        PORT = "[[.app.port]]"
        DC      = "Running on datacenter ${node.datacenter}"
        SSL_ENABLED = 1
        SENTRY_ENVIRONMENT = "[[.app.stand]]"
        MYSQL_HOST = "[[.mysql_srv]]"
        MYSQL_PORT = "[[.mysql_port]]"
        MYSQL_DATABASE = "[[.mysql_app_db]]"
        MYSQL_SSL_SUPPORT = "[[.mysql_ssl_support]]"
        REDIS_HOST = "[[.redis_host]]"
        REDIS_PORT = "[[.redis_port]]"
        CLICKHOUSE_HOST = "[[.clickhouse_url]]"
        CLICKHOUSE_PORT = "[[.clickhouse_port]]"
        CLICKHOUSE_DATABASE = "[[.clickhouse_ag_db]]"
        CLICKHOUSE_USER = "[[.app.env.app_clickhouse_user]]"
        MAX_INSTANCES = "[[.app.env.max_instances]]"
        PAY_URL = "[[.app.env.pay_url]]"
      }
      resources {
        cpu    =  [[.app.resources.cpu]]
        memory =  [[.app.resources.memory]]
      }
    }
  }
}