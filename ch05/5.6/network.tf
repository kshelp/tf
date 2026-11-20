locals {
  # 서브넷 정의: 이름 => { CIDR, AZ 접미사, 계층 }
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

  public_subnets  = { for k, v in local.subnets : k => v if v.tier == "public" }
  private_subnets = { for k, v in local.subnets : k => v if v.tier == "private" }
}

resource "aws_vpc" "mynet" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # Route 53 프라이빗 호스팅 영역 사용에 필요
  enable_dns_hostnames = true
  tags                 = { Name = "mynet" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.mynet.id
  tags   = { Name = "mynet-igw" }
}

resource "aws_subnet" "this" {
  for_each = local.subnets

  vpc_id                  = aws_vpc.mynet.id
  cidr_block              = each.value.cidr
  availability_zone       = var.azs[each.value.az]
  map_public_ip_on_launch = each.value.tier == "public"
  tags                    = { Name = each.key, Tier = each.value.tier }
}

# 가용 영역별 NAT 게이트웨이 (한 AZ 장애가 다른 AZ의 아웃바운드에 영향을 주지 않도록)
resource "aws_eip" "nat" {
  for_each = var.azs
  domain   = "vpc"
  tags     = { Name = "nat-eip-${each.key}" }
}

resource "aws_nat_gateway" "nat" {
  for_each = var.azs

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.this["public-subnet-${each.key}"].id
  tags          = { Name = "nat-${each.key}" }

  depends_on = [aws_internet_gateway.igw]
}

# 퍼블릭 라우팅: 0.0.0.0/0 → 인터넷 게이트웨이
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.mynet.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public-rt" }
}

# 프라이빗 라우팅: 0.0.0.0/0 → 같은 AZ의 NAT 게이트웨이
resource "aws_route_table" "private" {
  for_each = var.azs

  vpc_id = aws_vpc.mynet.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[each.key].id
  }
  tags = { Name = "private-rt-${each.key}" }
}

resource "aws_route_table_association" "public" {
  for_each       = local.public_subnets
  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each       = local.private_subnets
  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.private[each.value.az].id
}
