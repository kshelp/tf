terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "ch05-3tier-eks"
      ManagedBy = "terraform"
    }
  }
}

# 애플리케이션(k8s_app.tf) 배포용. 클러스터가 만들어진 뒤 aws eks get-token으로 인증한다.
# terraform을 실행하는 IAM 사용자는 클러스터 생성자로서 관리자 권한을 받는다(eks.tf).
provider "kubernetes" {
  host                   = aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.this.name, "--region", var.region]
  }
}
