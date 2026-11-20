variable "enable_file" {
  default = true
}

# 조건식 + count: 리소스 생성 여부를 제어한다.
resource "local_file" "foo" {
  count    = var.enable_file ? 1 : 0
  content  = "foo!"
  filename = "${path.module}/foo.bar"
}

output "content" {
  value = var.enable_file ? local_file.foo[0].content : ""
}

# 조건식의 양쪽 결과는 같은 유형이어야 한다.
variable "env" {
  default = "dev"
}

locals {
  instance_count = var.env == "prod" ? 3 : 1
  bucket_suffix  = var.env == "prod" ? "" : "-${var.env}"
}

output "instance_count" {
  value = local.instance_count
}

output "bucket_name" {
  value = "my-bucket${local.bucket_suffix}"
}
