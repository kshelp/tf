# 5.4.7 WAS 구성하기 - 6. LoadBalancer 구성하기, 7. Route 53에 레코드 등록
#   내부 NLB was-lb (was-subnet-a/b) TCP:5000 → was-tg → was1, was2 (Flask :5000)
#   WAS 애플리케이션 설치(1~5)는 서버에 접속해 직접 진행한다.

# ---------- 6-1. 대상 그룹 생성하기 ----------
#   대상 유형: 인스턴스 / 이름: was-tg / 프로토콜: TCP, 포트: 5000 / VPC: mynet
#   상태 검사: TCP (나머지는 콘솔 기본값)
resource "aws_lb_target_group" "was" {
  name        = "was-tg"
  target_type = "instance"
  protocol    = "TCP"
  port        = 5000
  vpc_id      = aws_vpc.mynet.id

  health_check {
    protocol            = "TCP"
    port                = "traffic-port"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 30
  }

  tags = { Name = "was-tg" }
}

# 대상 등록: was1, was2 → [아래에 보류 중인 것으로 포함]
resource "aws_lb_target_group_attachment" "was" {
  for_each = toset(["was1", "was2"])

  target_group_arn = aws_lb_target_group.was.arn
  target_id        = aws_instance.server[each.key].id
  port             = 5000
}

# ---------- 6-2. 로드 밸런서 생성하기 (Network Load Balancer) ----------
#   이름: was-lb / 체계: 내부 / 서브넷: was-subnet-a, was-subnet-b / 보안 그룹: was-lb-sg
resource "aws_lb" "was" {
  name               = "was-lb"
  load_balancer_type = "network"
  internal           = true
  subnets            = [aws_subnet.this["was-subnet-a"].id, aws_subnet.this["was-subnet-b"].id]
  security_groups    = [aws_security_group.was_lb.id]

  tags = { Name = "was-lb" }
}

# 리스너 및 라우팅: TCP 5000 → was-tg
resource "aws_lb_listener" "was" {
  load_balancer_arn = aws_lb.was.arn
  protocol          = "TCP"
  port              = 5000

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.was.arn
  }
}

# ---------- 7. Route 53에 레코드 등록: was.cloud.local ----------
# web 서버의 NGINX가 upstream으로 was.cloud.local:5000을 사용한다 (5.4.8 2-2).
resource "aws_route53_record" "was" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "was.cloud.local"
  type    = "CNAME"
  ttl     = 60
  records = [aws_lb.was.dns_name]
}
