# =============================================================================
# db_init.tf — DB 초기화 Job (kubernetes 프로바이더, versions.tf)
# -----------------------------------------------------------------------------
# 5.4.5 3. 데이터베이스와 사용자 생성 → Secret + Job db-init (mysql 클라이언트, was 노드에서 실행)
#
# web·was 앱(Deployment·Service·ConfigMap)은 테라폼이 아니라 Argo CD가 gitops/ 매니페스트로 배포한다(argocd.tf).
# DB 암호가 들어가는 Secret과 db-init Job만 테라폼이 관리한다(암호를 Git에 올리지 않기 위해).
#
# 요청 흐름 (구성도 images/architecture-eks-argocd.png)
#   ALB web-lb → web 노드 :30080 → NGINX 파드 → was.cloud.local:5000 (내부 NLB)
#   → was 노드 :30500 → Flask 파드 :5000 → db.cloud.local / redis.cloud.local
#
# 모든 리소스가 노드 그룹에 의존하도록 해 destroy 때 노드보다 먼저 삭제되게 한다.
# (노드가 먼저 사라지면 파드 종료·Job 삭제가 끝나지 않아 destroy가 멈출 수 있다)
# 네임스페이스를 지정하지 않았으므로 default 네임스페이스에 만들어진다(Argo CD 앱과 같은 곳).
# =============================================================================

# Secret: db-init Job에 넘길 접속 정보. data 값은 프로바이더가 base64로 인코딩해 저장한다.
# (base64는 암호화가 아니다. EKS는 etcd를 기본 암호화하지만, 값은 Terraform State에도 남는다)
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

# Job: 파드를 한 번 실행해 "성공적으로 끝나는 것"이 목적인 리소스 (Deployment처럼 계속 띄워 두지 않음)
# mysql 클라이언트 이미지로 RDS에 접속해 앱용 DB·사용자·테이블을 만든다.
resource "kubernetes_job_v1" "db_init" {
  metadata {
    name = "db-init"
  }

  spec {
    backoff_limit = 4 # 실패 시 최대 4번까지 재시도한 뒤 Job을 실패로 처리

    template {
      metadata {
        labels = { app = "db-init" }
      }
      spec {
        restart_policy = "OnFailure"      # Job 파드는 Never 또는 OnFailure만 가능. 실패하면 같은 파드에서 컨테이너 재시작
        node_selector  = { tier = "was" } # mysql-sg는 was-sg(와 bastion-sg)만 허용

        container {
          name  = "mysql"
          image = "mysql:8.4" # RDS와 같은 버전의 mysql 클라이언트를 쓰기 위해 공식 이미지 사용
          # Secret의 모든 키를 같은 이름의 환경 변수로 주입 (MYSQL_USER, MYSQL_PWD, APP_DB_PASSWORD)
          env_from {
            secret_ref {
              name = kubernetes_secret_v1.db_init.metadata[0].name
            }
          }
          # 다시 실행해도 안전하도록 IF NOT EXISTS를 쓴다.
          # 1) until 루프: DNS 레코드 전파·RDS 기동이 끝날 때까지 5초마다 접속을 재시도한다.
          # 2) 히어독(<<SQL ... SQL)으로 SQL 여러 줄을 mysql 클라이언트에 넘긴다.
          #    $APP_DB_PASSWORD는 셸이 환경 변수 값으로 치환한다.
          #    (Terraform 히어독에서 ${...}가 아니라 $NAME 형태이므로 Terraform은 건드리지 않는다)
          # 3) 마지막으로 테이블 목록을 출력해 kubectl logs job/db-init 로 결과를 확인할 수 있게 한다.
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

  # Job이 완료(성공)될 때까지 apply가 기다린다. 실패하거나 시간 초과면 apply가 오류로 끝난다.
  # → Argo CD Application(argocd.tf)은 DB가 준비된 뒤에 만들어진다.
  wait_for_completion = true
  timeouts {
    create = "10m"
    update = "10m"
  }

  # db.cloud.local 레코드가 있어야 접속할 수 있다. (RDS 인스턴스는 레코드가 참조하므로 간접적으로 먼저 생성됨)
  depends_on = [aws_eks_node_group.this, aws_route53_record.db]
}
