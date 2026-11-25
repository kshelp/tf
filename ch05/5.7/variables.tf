variable "region" {
  type        = string
  description = "배포를 허용할 리전 (5.6의 region과 같아야 한다)"
  default     = "ap-northeast-2"
}

variable "environments" {
  type = map(object({
    user        = string
    require_mfa = optional(bool, false)
    admin       = optional(bool, false) # true면 사용자에게 AdministratorAccess를 직접 붙인다
  }))
  description = "환경 => 배포 사용자. 사용자는 자기 환경의 배포 역할 tf-deployer-<env>만 맡을(AssumeRole) 수 있다(admin = true면 계정 전체 관리자)"
  default = {
    dev  = { user = "user1", admin = true }
    stg  = { user = "user2" }
    prod = { user = "user3" }
  }
  validation {
    condition     = alltrue([for k in keys(var.environments) : can(regex("^[a-z0-9]+$", k))])
    error_message = "환경 이름은 영문 소문자와 숫자만 쓴다(리소스 이름 접두사로 쓰인다)."
  }
}

variable "state_bucket_name" {
  type        = string
  description = "Terraform State 버킷 이름. null이면 tfstate-<계정 ID>-<리전>"
  default     = null
}

variable "state_key_prefix" {
  type        = string
  description = "State 객체 경로 접두사. 환경별 키는 <접두사>/<env>/terraform.tfstate (5.6/env/*.s3.tfbackend와 같아야 한다)"
  default     = "ch05/5.6"
}

variable "max_session_duration" {
  type        = number
  description = "배포 역할 세션 최대 시간(초). EKS 생성·삭제가 오래 걸리므로 1시간보다 길게 둔다"
  default     = 14400
}

variable "console_access" {
  type        = bool
  description = "true면 사용자에게 콘솔 로그인 암호(초기 암호, 첫 로그인 시 변경)를 만든다. 실습용: 초기 암호가 State에 평문으로 남는다"
  default     = true
}
