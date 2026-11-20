# ---------------------------------------------------------------
# data 블록: 이미 AWS에 있는 정보를 "조회"만 한다 (새로 만들지 않음)
# 여기서는 EC2를 띄울 때 쓸 Amazon Linux 2 AMI(서버 이미지)를 찾는다.
# ---------------------------------------------------------------
data "aws_ami" "amzn2" {
  most_recent = true       # 조건에 맞는 AMI가 여러 개면 가장 최신 것을 선택
  owners      = ["amazon"] # Amazon이 공식 배포한 AMI만 검색 (비공식 이미지 제외)

  # AMI 이름으로 필터링
  filter {
    name   = "name"             # 필터 기준: AMI 이름
    values = ["amzn2-ami-hvm*"] # "amzn2-ami-hvm"으로 시작하는 이름 (* = 와일드카드)
  }
}

# ---------------------------------------------------------------
# resource 블록: AWS에 실제로 EC2 인스턴스(가상 서버)를 "생성"한다
# 참조 이름: aws_instance.app_server
# ---------------------------------------------------------------
resource "aws_instance" "app_server" {
  ami           = data.aws_ami.amzn2.id # 위 data 블록에서 찾은 AMI의 ID를 사용
  instance_type = "t2.micro"            # 인스턴스 크기 (vCPU 1개, 메모리 1GiB, 프리 티어 대상)

  # 태그: 콘솔의 EC2 목록에서 "Name" 열에 이 이름이 표시된다
  tags = { Name = "TerraformAppServerInstance" }
}
