resource "local_file" "my_var" {
  content  = var.my_var
  filename = "${path.module}/my_var.txt"
}

output "list_index_0" {
  value = var.list[0]
}

output "list_upper" {
  value = [for name in var.list : upper(name)]
}

output "map" {
  value = var.map
}

output "set" {
  value = var.set
}

output "object_name" {
  value = var.object.name
}

output "ingress_rules" {
  value = var.ingress_rules
}

output "db_password" {
  value     = var.db_password
  sensitive = true # 민감 변수를 출력하려면 output에도 sensitive를 지정해야 한다
}
