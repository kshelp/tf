terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# 리전과 자격증명은 환경 변수(AWS_DEFAULT_REGION, AWS_ACCESS_KEY_ID 등)에서 읽는다.
provider "aws" {
  default_tags { # 이 프로바이더로 만드는 모든 리소스에 공통 태그 적용
    tags = {
      ManagedBy = "terraform"
      Chapter   = "4.2.1"
    }
  }
}

# 최신 Amazon Linux 2023 AMI 조회
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "app_server" {
  ami           = data.aws_ami.al2023.id
  instance_type = "t3.micro"
  tags          = { Name = "TerraformAppServerInstance" }
}

output "ami_id" {
  value = data.aws_ami.al2023.id
}

output "instance_id" {
  value = aws_instance.app_server.id
}

output "public_ip" {
  value = aws_instance.app_server.public_ip
}
