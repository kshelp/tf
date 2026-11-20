# map으로 반복: each.key, each.value
resource "local_file" "abc" {
  for_each = {
    a = "content a"
    b = "content b"
  }
  content  = each.value
  filename = "${path.module}/${each.key}.txt"
}

# set으로 반복: each.key == each.value
variable "names" {
  type    = set(string)
  default = ["x", "y"]
}

resource "local_file" "def" {
  for_each = var.names
  content  = "name=${each.value}"
  filename = "${path.module}/def-${each.key}.txt"
}

# list를 for_each에 쓰려면 toset()으로 변환한다.
resource "local_file" "ghi" {
  for_each = toset(["p", "q"])
  content  = each.key
  filename = "${path.module}/ghi-${each.key}.txt"
}

output "abc_a" {
  value = local_file.abc["a"].content # 키로 접근
}
