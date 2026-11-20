terraform {
  required_version = ">= 1.7" # mock_provider는 1.7+
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

variable "prefix" {
  type    = string
  default = "test"
}

variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "The environment value must be dev, qa, or prod."
  }
}

variable "address_space" {
  type    = string
  default = "10.0.0.0/16"
}

resource "aws_vpc" "hashicat" {
  cidr_block = var.address_space
  tags = {
    name        = "${var.prefix}-vpc"
    environment = var.environment
  }
}

resource "aws_subnet" "hashicat" {
  vpc_id     = aws_vpc.hashicat.id
  cidr_block = cidrsubnet(var.address_space, 8, 10)
}

output "vpc_id" {
  value = aws_vpc.hashicat.id
}

output "subnet_cidr" {
  value = aws_subnet.hashicat.cidr_block
}
