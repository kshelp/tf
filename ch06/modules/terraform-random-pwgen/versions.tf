terraform {
  required_version = ">= 1.6"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5" # 재사용 모듈은 최소 버전만 지정한다
    }
  }
}
