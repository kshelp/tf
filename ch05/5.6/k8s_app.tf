# 5.4에서 서버에 접속해 손으로 하던 애플리케이션 구성을 쿠버네티스 리소스로 옮긴다.
#   5.4.5 3. 데이터베이스와 사용자 생성     → Job db-init (mysql 클라이언트, was 노드에서 실행)
#   5.4.7 1~5 WAS(Flask) 설치·서비스 등록   → Deployment was (2개, was 노드) + Service was (NodePort 30500)
#   5.4.8 1~2 Web(NGINX) 설치·프록시 설정   → Deployment web (2개, web 노드) + Service web (NodePort 30080)
#                                           + ConfigMap web-nginx (lb.conf와 같은 내용)
#
# 요청 흐름은 5.4와 같다.
#   ALB web-lb → web 노드 :30080 → NGINX 파드 → was.cloud.local:5000 (내부 NLB)
#   → was 노드 :30500 → Flask 파드 :5000 → db.cloud.local / redis.cloud.local
# 파드는 CoreDNS → VPC DNS를 거치므로 Route 53 프라이빗 호스팅 영역(cloud.local)을 그대로 조회한다.
#
# 모든 리소스가 노드 그룹에 의존하도록 해 destroy 때 노드보다 먼저 삭제되게 한다.

locals {
  app_labels = {
    web = { app = "web" }
    was = { app = "was" }
  }
}

# ---------- 5.4.5 3. 데이터베이스와 애플리케이션 사용자 생성 ----------
resource "kubernetes_secret_v1" "db_init" {
  metadata {
    name = "db-init"
  }
  data = {
    MYSQL_USER      = var.db_username
    MYSQL_PWD       = var.db_password # mysql 클라이언트가 읽는 환경 변수
    APP_DB_PASSWORD = var.app_db_password
  }

  depends_on = [aws_eks_node_group.this]
}

resource "kubernetes_job_v1" "db_init" {
  metadata {
    name = "db-init"
  }

  spec {
    backoff_limit = 4

    template {
      metadata {
        labels = { app = "db-init" }
      }
      spec {
        restart_policy = "OnFailure"
        node_selector  = { tier = "was" } # mysql-sg는 was-sg(와 bastion-sg)만 허용

        container {
          name  = "mysql"
          image = "mysql:8.4"
          env_from {
            secret_ref {
              name = kubernetes_secret_v1.db_init.metadata[0].name
            }
          }
          # 다시 실행해도 안전하도록 IF NOT EXISTS를 쓴다.
          command = ["sh", "-c", <<-EOT
            until mysql -h db.cloud.local -u "$MYSQL_USER" -e 'SELECT 1' >/dev/null 2>&1; do
              echo "waiting for db.cloud.local"; sleep 5
            done
            mysql -h db.cloud.local -u "$MYSQL_USER" <<SQL
            CREATE DATABASE IF NOT EXISTS frodo CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
            CREATE USER IF NOT EXISTS 'frodo'@'%' IDENTIFIED BY '$APP_DB_PASSWORD';
            GRANT ALL PRIVILEGES ON frodo.* TO 'frodo'@'%';
            CREATE TABLE IF NOT EXISTS frodo.users (
              id       INT AUTO_INCREMENT PRIMARY KEY,
              username VARCHAR(50)  NOT NULL,
              password VARCHAR(255) NOT NULL
            );
            SQL
            mysql -h db.cloud.local -u "$MYSQL_USER" -e 'SHOW TABLES FROM frodo'
          EOT
          ]
        }
      }
    }
  }

  wait_for_completion = true
  timeouts {
    create = "10m"
    update = "10m"
  }

  depends_on = [aws_eks_node_group.this, aws_route53_record.db]
}

# ---------- 5.4.7 WAS(Flask) ----------
# 학습자료와 같은 패키지를 설치하고 mywas2를 받아 실행한다(python 이미지에 빌드 도구와 MariaDB 개발 패키지가 들어 있다).
# app.py는 db.cloud.local(frodo), redis.cloud.local(TLS)을 사용한다.
resource "kubernetes_deployment_v1" "was" {
  metadata {
    name   = "was"
    labels = local.app_labels.was
  }

  spec {
    replicas = 2 # was1, was2

    selector {
      match_labels = local.app_labels.was
    }

    template {
      metadata {
        labels = local.app_labels.was
      }
      spec {
        node_selector = { tier = "was" }

        # 가용 영역마다 하나씩 (was1: 2a, was2: 2c)
        topology_spread_constraint {
          max_skew           = 1
          topology_key       = "topology.kubernetes.io/zone"
          when_unsatisfiable = "DoNotSchedule"
          label_selector {
            match_labels = local.app_labels.was
          }
        }

        container {
          name        = "was"
          image       = "python:3.12-bookworm"
          working_dir = "/app"
          command = ["sh", "-c", <<-EOT
            set -e
            pip install --no-cache-dir --root-user-action=ignore \
              Flask Flask-WTF Flask-Login Flask-MySQLdb mysqlclient Flask-Session Werkzeug redis
            git clone ${var.was_app_repo} /app/mywas2
            cd /app/mywas2 && git checkout ${var.was_app_ref}
            exec python3 app.py
          EOT
          ]

          port {
            container_port = 5000
          }

          # 패키지 설치(mysqlclient 빌드 포함)에 1~2분 걸린다.
          startup_probe {
            http_get {
              path = "/healthz"
              port = 5000
            }
            period_seconds    = 5
            failure_threshold = 60
          }
          readiness_probe {
            http_get {
              path = "/healthz"
              port = 5000
            }
            period_seconds = 10
          }

          resources {
            requests = { cpu = "100m", memory = "256Mi" }
          }
        }
      }
    }
  }

  timeouts {
    create = "15m"
    update = "15m"
  }

  depends_on = [
    aws_eks_node_group.this,
    kubernetes_job_v1.db_init,
    aws_route53_record.redis,
  ]
}

# NLB(was-tg)가 노드의 30500 포트로 보내면 kube-proxy가 was 파드 :5000으로 전달한다.
resource "kubernetes_service_v1" "was" {
  metadata {
    name = "was"
  }
  spec {
    type     = "NodePort"
    selector = local.app_labels.was
    port {
      port        = 5000
      target_port = 5000
      node_port   = var.was_node_port
      protocol    = "TCP"
    }
  }

  depends_on = [aws_eks_node_group.this]
}

# ---------- 5.4.8 Web(NGINX) ----------
# /etc/nginx/conf.d/lb.conf와 같은 내용. 컨테이너의 기본 서버 설정(default.conf)을 대신한다.
resource "kubernetes_config_map_v1" "web_nginx" {
  metadata {
    name = "web-nginx"
  }
  data = {
    "default.conf" = <<-EOT
      upstream backend_servers {
          server was.cloud.local:5000;
      }

      server {
          listen 80;
          location / {
              proxy_pass http://backend_servers;
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          }
      }
    EOT
  }

  depends_on = [aws_eks_node_group.this]
}

resource "kubernetes_deployment_v1" "web" {
  metadata {
    name   = "web"
    labels = local.app_labels.web
  }

  spec {
    replicas = 2 # web1, web2

    selector {
      match_labels = local.app_labels.web
    }

    template {
      metadata {
        labels = local.app_labels.web
        annotations = {
          # 설정이 바뀌면 파드를 다시 만들어 NGINX가 새 설정을 읽게 한다.
          "config-hash" = sha256(kubernetes_config_map_v1.web_nginx.data["default.conf"])
        }
      }
      spec {
        node_selector = { tier = "web" }

        topology_spread_constraint {
          max_skew           = 1
          topology_key       = "topology.kubernetes.io/zone"
          when_unsatisfiable = "DoNotSchedule"
          label_selector {
            match_labels = local.app_labels.web
          }
        }

        container {
          name  = "nginx"
          image = "nginx:1.28"

          port {
            container_port = 80
          }

          volume_mount {
            name       = "conf"
            mount_path = "/etc/nginx/conf.d"
            read_only  = true
          }

          readiness_probe {
            tcp_socket {
              port = 80
            }
            period_seconds = 10
          }

          resources {
            requests = { cpu = "50m", memory = "64Mi" }
          }
        }

        volume {
          name = "conf"
          config_map {
            name = kubernetes_config_map_v1.web_nginx.metadata[0].name
          }
        }
      }
    }
  }

  # NGINX는 시작할 때 was.cloud.local을 조회하므로 레코드와 WAS가 먼저 준비되어야 한다.
  depends_on = [
    aws_eks_node_group.this,
    aws_route53_record.was,
    aws_lb_listener.was,
    kubernetes_deployment_v1.was,
  ]
}

# ALB(web-tg)가 노드의 30080 포트로 보내면 kube-proxy가 web 파드 :80으로 전달한다.
resource "kubernetes_service_v1" "web" {
  metadata {
    name = "web"
  }
  spec {
    type     = "NodePort"
    selector = local.app_labels.web
    port {
      port        = 80
      target_port = 80
      node_port   = var.web_node_port
      protocol    = "TCP"
    }
  }

  depends_on = [aws_eks_node_group.this]
}
