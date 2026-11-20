# 모듈 안에는 provider 블록을 두지 않는다. 호출하는 루트 모듈의 프로바이더를 사용한다.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "this" {
  ami           = data.aws_ami.al2023.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  tags          = merge(var.tags, { Name = var.instance_name })
}
