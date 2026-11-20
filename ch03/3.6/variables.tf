# 기본 유형
variable "string" {
  type        = string
  description = "var String"
  default     = "myString"
}

variable "number" {
  type    = number
  default = 123
}

variable "boolean" {
  default = true # type을 생략하면 default 값으로 유형을 추론한다
}

# 컬렉션 유형
variable "list" {
  type    = list(string)
  default = ["google", "vmware", "amazon", "microsoft"]
}

variable "map" { # 키 기준으로 정렬된다
  type = map(string)
  default = {
    aws   = "amazon"
    azure = "microsoft"
    gcp   = "google"
  }
}

variable "set" { # 중복이 제거되고 값 기준으로 정렬된다
  type    = set(string)
  default = ["google", "vmware", "amazon", "microsoft", "google"]
}

# 구조 유형
variable "object" {
  type = object({ name = string, age = number })
  default = {
    name = "abc"
    age  = 12
  }
}

variable "tuple" {
  type    = tuple([string, number, bool])
  default = ["abc", 123, true]
}

# optional 속성 (1.3+)
variable "ingress_rules" {
  type = list(object({
    port        = number
    description = optional(string)
    protocol    = optional(string, "tcp")
  }))
  default = [
    { port = 80, description = "web" },
    { port = 53, protocol = "udp" },
  ]
}

# 유효성 검사
variable "instance_type" {
  type        = string
  description = "EC2 인스턴스 유형"
  default     = "t3.micro"
  validation {
    condition     = contains(["t3.micro", "t3.small"], var.instance_type)
    error_message = "instance_type은 t3.micro 또는 t3.small만 허용한다."
  }
}

# 민감 변수
variable "db_password" {
  type      = string
  default   = "changeme"
  sensitive = true
}

# 우선순위 실습용 변수
variable "my_var" {
  default = "var1(default)"
}
