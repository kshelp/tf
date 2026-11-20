variable "names" {
  default = ["a", "b", "c"]
}

variable "members" {
  default = {
    alice = { role = "admin", age = 30 }
    bob   = { role = "user", age = 25 }
    carol = { role = "user", age = 35 }
  }
}

resource "local_file" "abc" {
  content  = jsonencode([for s in var.names : upper(s)]) # ["A","B","C"]
  filename = "${path.module}/abc.txt"
}

output "list_to_list" {
  value = [for i, v in var.names : "${i}:${v}"] # 인덱스와 값
}

output "list_to_map" {
  value = { for s in var.names : s => upper(s) }
}

output "filtered" {
  value = [for name, m in var.members : name if m.role == "user"] # if 필터
}

output "grouped" {
  value = { for name, m in var.members : m.role => name... } # ... 그룹화
}
