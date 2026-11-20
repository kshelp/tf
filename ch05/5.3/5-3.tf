terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  required_version = ">= 1.6"
}

provider "aws" {
  region = "ap-northeast-2"
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "web" {
  count         = terraform.workspace == "default" ? 3 : 1
  ami           = data.aws_ami.al2023.id
  instance_type = "t3.micro"
  tags = {
    Name = "HelloWorld-${terraform.workspace}-${count.index + 1}"
  }
}
