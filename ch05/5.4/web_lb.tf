# =============================================================================
# web_lb.tf — 외부(인터넷) Application Load Balancer: web-lb
# -----------------------------------------------------------------------------
# 5.4.8 Web VM 구성하기 - 3. 로드 밸런서 구성하기
#   외부 ALB web-lb (public-subnet-a/b) HTTP:80 → web-tg → web1, web2 (NGINX :80)
#   NGINX 설치와 설정(1~2)은 서버에 접속해 직접 진행한다.
#
# 구성 요소 관계
#   aws_lb(ALB) ── aws_lb_listener(HTTP:80) ──forward──▶ aws_lb_target_group(web-tg)
#                                                           ▲
#                    aws_lb_target_group_attachment ────────┘ (web1, web2 인스턴스를 등록)
# =============================================================================

# ---------- 3-1. 대상 그룹 생성하기 ----------
#   대상 유형: 인스턴스 / 이름: web-tg / 프로토콜: HTTP, 포트: 80 / VPC: mynet
#   상태 검사 경로: /healthz (NGINX가 was로 프록시 → Flask의 /healthz가 응답)
#   → 상태 검사가 web·was 두 계층을 모두 통과해야 healthy 가 된다.
#     NGINX·Flask 설치를 마치기 전에는 대상이 unhealthy로 보이는 것이 정상이다.
resource "aws_lb_target_group" "web" {
  name        = "web-tg"   # 대상 그룹 이름은 32자 이하, 계정·리전 안에서 고유
  target_type = "instance" # 대상 = EC2 인스턴스. 트래픽은 인스턴스의 아래 port로 간다
  protocol    = "HTTP"
  port        = 80
  vpc_id      = aws_vpc.mynet.id

  health_check {
    protocol            = "HTTP"
    path                = "/healthz"
    port                = "traffic-port" # 트래픽 포트(80)와 같은 포트로 검사
    matcher             = "200"          # HTTP 200 응답만 정상으로 판단
    healthy_threshold   = 5              # 연속 5회 성공 → healthy
    unhealthy_threshold = 2              # 연속 2회 실패 → unhealthy
    timeout             = 5              # 초
    interval            = 30             # 초
  }

  tags = { Name = "web-tg" }
}

# 대상 등록: web1, web2 → [아래에 보류 중인 것으로 포함]
# toset으로 서버 이름 집합을 만들고 for_each로 인스턴스마다 등록 리소스를 하나씩 만든다.
resource "aws_lb_target_group_attachment" "web" {
  for_each = toset(["web1", "web2"])

  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.server[each.key].id # ec2.tf의 for_each 인스턴스를 이름으로 참조
  port             = 80
}

# ---------- 3-2. 로드 밸런서 생성하기 (Application Load Balancer) ----------
#   이름: web-lb / 체계: 인터넷 경계 / 서브넷: public-subnet-a, public-subnet-b
#   보안 그룹: default, web-lb-sg
resource "aws_lb" "web" {
  name               = "web-lb"
  load_balancer_type = "application" # L7(HTTP/HTTPS) 로드 밸런서
  internal           = false         # 인터넷 경계(공인 DNS 이름을 가짐)
  # ALB는 서로 다른 AZ의 서브넷 2개 이상이 필요하다. 인터넷 경계이므로 퍼블릭 서브넷에 둔다.
  subnets         = [aws_subnet.this["public-subnet-a"].id, aws_subnet.this["public-subnet-b"].id]
  security_groups = [aws_vpc.mynet.default_security_group_id, aws_security_group.web_lb.id]

  tags = { Name = "web-lb" }
}

# 리스너 및 라우팅: HTTP 80 → web-tg
# 리스너 = 로드 밸런서가 요청을 받는 포트/프로토콜과, 받은 요청을 어디로 보낼지(규칙)의 묶음
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  protocol          = "HTTP"
  port              = 80

  # 기본 동작: 모든 요청을 web-tg로 전달
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
