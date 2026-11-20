variable "content" {
  type = string
}

variable "filename" {
  type = string
}

resource "local_file" "this" {
  content  = var.content
  filename = var.filename
}

output "id" {
  value = local_file.this.id
}
