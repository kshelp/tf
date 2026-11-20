# 5.4.7 WAS 구성하기 - 6. LoadBalancer 구성하기, 7. Route 53에 레코드 등록
#   내부 NLB was-lb (was-subnet-a/b) TCP:5000 → was-tg → was 노드 그룹 :30500(NodePort) → Flask 파드 :5000
#   5.4와 달리 대상은 was1·was2 인스턴스가 아니라 was 노드 그룹의 오토 스케일링 그룹이다.

# ---------- 6-1. 대상 그룹 생성하기 ----------
#   대상 유형: 인스턴스 / 이름: was-tg / 프로토콜: TCP, 포트: 30500(was 서비스 NodePort) / VPC: mynet
#   상태 검사: TCP (나머지는 콘솔 기본값)
resource "aws_lb_target_group" "was" {
  name        = "was-tg"
  target_type = "instance"
  protocol    = "TCP"
  port        = var.was_node_port
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

# 대상 등록: was 노드 그룹의 ASG에 대상 그룹을 연결하면 노드가 바뀌어도 자동으로 등록·해제된다.
resource "aws_autoscaling_attachment" "was" {
  autoscaling_group_name = aws_eks_node_group.this["was"].resources[0].autoscaling_groups[0].name
  lb_target_group_arn    = aws_lb_target_group.was.arn
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
# web 파드의 NGINX가 upstream으로 was.cloud.local:5000을 사용한다 (5.4.8 2-2, k8s_app.tf).
resource "aws_route53_record" "was" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "was.cloud.local"
  type    = "CNAME"
  ttl     = 60
  records = [aws_lb.was.dns_name]
}
