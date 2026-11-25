# =============================================================================
# was_lb.tf — 내부 Network Load Balancer: was-lb + 내부 DNS 레코드(was.cloud.local)
# -----------------------------------------------------------------------------
# 5.4.7 WAS 구성하기 - 6. LoadBalancer 구성하기, 7. Route 53에 레코드 등록
#   내부 NLB was-lb (was-subnet-a/b) TCP:5000 → was-tg → was 노드 그룹 :30500(NodePort) → Flask 파드 :5000
#   5.4와 달리 대상은 was1·was2 인스턴스가 아니라 was 노드 그룹의 오토 스케일링 그룹이다.
#
# web 계층(NGINX 파드)은 was.cloud.local:5000 하나만 바라보고, NLB가 was 노드 2대로 분산한다.
# =============================================================================

# ---------- 6-1. 대상 그룹 생성하기 ----------
#   대상 유형: 인스턴스 / 이름: was-tg / 프로토콜: TCP, 포트: 30500(was 서비스 NodePort) / VPC: mynet
#   상태 검사: TCP (나머지는 콘솔 기본값)
resource "aws_lb_target_group" "was" {
  name        = "${var.env}-was-tg"
  target_type = "instance"
  protocol    = "TCP"             # L4. 패킷 내용을 보지 않고 TCP 연결 단위로 전달
  port        = var.was_node_port # 30500
  vpc_id      = aws_vpc.mynet.id

  # TCP 상태 검사: 30500 포트로 TCP 연결(3-way handshake)이 맺어지면 정상
  health_check {
    protocol            = "TCP"
    port                = "traffic-port"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 10 # 초
    interval            = 30 # 초
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
  name               = "${var.env}-was-lb"
  load_balancer_type = "network" # L4(TCP/UDP) 로드 밸런서
  internal           = true      # 내부 전용: DNS 이름이 사설 IP로만 해석된다
  subnets            = [aws_subnet.this["was-subnet-a"].id, aws_subnet.this["was-subnet-b"].id]
  # NLB 보안 그룹은 생성 시에만 지정할 수 있다(나중에 처음 추가하려면 NLB를 다시 만들어야 함).
  security_groups = [aws_security_group.was_lb.id]

  tags = { Name = "was-lb" }
}

# 리스너 및 라우팅: TCP 5000 → was-tg
# 클라이언트는 NLB의 5000번으로 접속하고, NLB는 노드의 30500번(대상 그룹 포트)으로 전달한다.
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
# web 파드의 NGINX가 upstream으로 was.cloud.local:5000을 사용한다 (5.4.8 2-2, gitops/default.conf).
# was.cloud.local → internal-<env>-was-lb-xxxx.elb.ap-northeast-2.amazonaws.com
resource "aws_route53_record" "was" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "was.cloud.local"
  type    = "CNAME"
  ttl     = 60
  records = [aws_lb.was.dns_name]
}
