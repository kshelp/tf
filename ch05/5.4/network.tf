# =============================================================================
# network.tf — VPC, 서브넷, 인터넷/NAT 게이트웨이, 라우팅 테이블
# -----------------------------------------------------------------------------
# 구성 (VPC mynet 10.0.0.0/16, 가용 영역 2개)
#
#                 AZ a (ap-northeast-2a)        AZ b (ap-northeast-2c)
#   public  :  public-subnet-a 10.0.0.0/24   public-subnet-b 10.0.1.0/24   ← ALB, NAT GW, bastion
#   web     :  web-subnet-a    10.0.10.0/24  web-subnet-b    10.0.11.0/24  ← web1, web2
#   was     :  was-subnet-a    10.0.20.0/24  was-subnet-b    10.0.21.0/24  ← was1, was2, 내부 NLB
#   db      :  db-subnet-a     10.0.30.0/24  db-subnet-b     10.0.31.0/24  ← RDS, ElastiCache
#
#   public  서브넷 → 인터넷 게이트웨이(igw)로 직접 나간다.
#   private 서브넷 → 같은 AZ의 NAT 게이트웨이를 거쳐 나간다(외부에서 들어오는 연결은 불가).
#
# /24 서브넷 하나는 256개 주소지만 AWS가 5개(.0 .1 .2 .3 .255)를 예약하므로 251개를 쓸 수 있다.
# =============================================================================

locals {
  # 서브넷 정의: 이름 => { CIDR, AZ 접미사, 계층 }
  # 서브넷을 추가·삭제하려면 이 맵만 고치면 된다(aws_subnet.this가 for_each로 생성).
  # 맵의 키(서브넷 이름)가 리소스 주소가 되므로, 다른 파일에서 aws_subnet.this["web-subnet-a"]처럼 참조한다.
  subnets = {
    "public-subnet-a" = { cidr = "10.0.0.0/24", az = "a", tier = "public" }
    "public-subnet-b" = { cidr = "10.0.1.0/24", az = "b", tier = "public" }
    "web-subnet-a"    = { cidr = "10.0.10.0/24", az = "a", tier = "private" }
    "web-subnet-b"    = { cidr = "10.0.11.0/24", az = "b", tier = "private" }
    "was-subnet-a"    = { cidr = "10.0.20.0/24", az = "a", tier = "private" }
    "was-subnet-b"    = { cidr = "10.0.21.0/24", az = "b", tier = "private" }
    "db-subnet-a"     = { cidr = "10.0.30.0/24", az = "a", tier = "private" }
    "db-subnet-b"     = { cidr = "10.0.31.0/24", az = "b", tier = "private" }
  }

  # for 표현식으로 계층별 부분 맵을 만든다. 라우팅 테이블 연결(아래)과 outputs.tf에서 사용한다.
  public_subnets  = { for k, v in local.subnets : k => v if v.tier == "public" }
  private_subnets = { for k, v in local.subnets : k => v if v.tier == "private" }
}

# ---------- VPC ----------
resource "aws_vpc" "mynet" {
  cidr_block = var.vpc_cidr

  # 두 옵션 모두 켜야 VPC 안에서 Amazon DNS(VPC CIDR +2 주소)로 이름 해석이 되고,
  # Route 53 프라이빗 호스팅 영역(cloud.local, dns.tf)을 쓸 수 있다.
  enable_dns_support   = true # Route 53 프라이빗 호스팅 영역 사용에 필요
  enable_dns_hostnames = true # 인스턴스에 DNS 호스트 이름 부여

  tags = { Name = "mynet" }
}

# ---------- 인터넷 게이트웨이 ----------
# 퍼블릭 서브넷이 인터넷과 직접 통신하기 위한 관문. VPC당 하나.
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.mynet.id
  tags   = { Name = "mynet-igw" }
}

# ---------- 서브넷 (8개) ----------
resource "aws_subnet" "this" {
  for_each = local.subnets # each.key = 서브넷 이름, each.value = { cidr, az, tier }

  vpc_id            = aws_vpc.mynet.id
  cidr_block        = each.value.cidr
  availability_zone = var.azs[each.value.az] # "a" → ap-northeast-2a, "b" → ap-northeast-2c

  # 퍼블릭 서브넷에서 시작하는 인스턴스(bastion)에만 공인 IP를 자동 할당한다.
  map_public_ip_on_launch = each.value.tier == "public"

  tags = { Name = each.key, Tier = each.value.tier }
}

# ---------- NAT 게이트웨이 (AZ마다 1개) ----------
# 가용 영역별 NAT 게이트웨이 (한 AZ 장애가 다른 AZ의 아웃바운드에 영향을 주지 않도록)
# 프라이빗 서브넷의 서버(web·was)는 NAT를 통해 dnf·pip 패키지, git 소스를 내려받는다.
# 비용 참고: NAT 게이트웨이는 시간당 요금 + 처리 데이터 요금이 붙으므로 실습 후 destroy 할 것.

# NAT 게이트웨이에 붙일 고정 공인 IP(탄력적 IP)
resource "aws_eip" "nat" {
  for_each = var.azs # 키 a, b
  domain   = "vpc"
  tags     = { Name = "nat-eip-${each.key}" }
}

resource "aws_nat_gateway" "nat" {
  for_each = var.azs

  allocation_id = aws_eip.nat[each.key].id
  # NAT 게이트웨이는 반드시 "퍼블릭" 서브넷에 둔다. AZ a → public-subnet-a, AZ b → public-subnet-b
  subnet_id = aws_subnet.this["public-subnet-${each.key}"].id
  tags      = { Name = "nat-${each.key}" }

  # IGW가 붙기 전에 NAT를 만들면 동작하지 않으므로 생성 순서를 명시한다(AWS 문서 권장).
  depends_on = [aws_internet_gateway.igw]
}

# ---------- 라우팅 테이블 ----------
# 퍼블릭 라우팅: 0.0.0.0/0 → 인터넷 게이트웨이
# (VPC 내부 10.0.0.0/16 경로는 local 경로로 자동 포함된다)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.mynet.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public-rt" }
}

# 프라이빗 라우팅: 0.0.0.0/0 → 같은 AZ의 NAT 게이트웨이
# AZ마다 라우팅 테이블을 따로 두어야 AZ별 NAT로 나갈 수 있다(private-rt-a, private-rt-b).
resource "aws_route_table" "private" {
  for_each = var.azs

  vpc_id = aws_vpc.mynet.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[each.key].id
  }
  tags = { Name = "private-rt-${each.key}" }
}

# 퍼블릭 서브넷 2개 → public-rt
resource "aws_route_table_association" "public" {
  for_each       = local.public_subnets
  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.public.id
}

# 프라이빗 서브넷 6개 → 자기 AZ의 private-rt
# 예) web-subnet-a(az = "a") → private-rt-a → nat-a
resource "aws_route_table_association" "private" {
  for_each       = local.private_subnets
  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.private[each.value.az].id
}
