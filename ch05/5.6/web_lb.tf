# 5.4.8 Web VM 구성하기 - 3. 로드 밸런서 구성하기
#   외부 ALB web-lb (public-subnet-a/b) HTTP:80 → web-tg → web 노드 그룹 :30080(NodePort) → NGINX 파드 :80
#   5.4와 달리 대상은 web1·web2 인스턴스가 아니라 web 노드 그룹의 오토 스케일링 그룹이다.

# ---------- 3-1. 대상 그룹 생성하기 ----------
#   대상 유형: 인스턴스 / 이름: web-tg / 프로토콜: HTTP, 포트: 30080(web 서비스 NodePort) / VPC: mynet
#   상태 검사 경로: /healthz (NGINX가 was로 프록시 → Flask의 /healthz가 응답)
resource "aws_lb_target_group" "web" {
  name        = "web-tg"
  target_type = "instance"
  protocol    = "HTTP"
  port        = var.web_node_port
  vpc_id      = aws_vpc.mynet.id

  health_check {
    protocol            = "HTTP"
    path                = "/healthz"
    port                = "traffic-port"
    matcher             = "200"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
  }

  tags = { Name = "web-tg" }
}

# 대상 등록: web 노드 그룹의 ASG에 대상 그룹을 연결
resource "aws_autoscaling_attachment" "web" {
  autoscaling_group_name = aws_eks_node_group.this["web"].resources[0].autoscaling_groups[0].name
  lb_target_group_arn    = aws_lb_target_group.web.arn
}

# ---------- 3-2. 로드 밸런서 생성하기 (Application Load Balancer) ----------
#   이름: web-lb / 체계: 인터넷 경계 / 서브넷: public-subnet-a, public-subnet-b
#   보안 그룹: default, web-lb-sg
resource "aws_lb" "web" {
  name               = "web-lb"
  load_balancer_type = "application"
  internal           = false
  subnets            = [aws_subnet.this["public-subnet-a"].id, aws_subnet.this["public-subnet-b"].id]
  security_groups    = [aws_vpc.mynet.default_security_group_id, aws_security_group.web_lb.id]

  tags = { Name = "web-lb" }
}

# 리스너 및 라우팅: HTTP 80 → web-tg
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  protocol          = "HTTP"
  port              = 80

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
