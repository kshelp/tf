terraform {
  required_version = ">= 1.4"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

variable "app_version" {
  default = "v1"
}

resource "local_file" "app" {
  content  = "app ${var.app_version}"
  filename = "${path.module}/app.txt"
}

# 1) null_resource: triggers 값이 바뀌면 교체(재실행)된다. null 프로바이더 필요
resource "null_resource" "deploy" {
  triggers = {
    app_hash = local_file.app.content_sha1
  }

  provisioner "local-exec" {
    command = "echo '[null_resource] deploy ${var.app_version}' >> deploy.log"
  }
}

# 2) terraform_data: 1.4+ 내장 리소스. 별도 프로바이더가 필요 없다.
resource "terraform_data" "deploy" {
  triggers_replace = [local_file.app.content_sha1]
  input            = var.app_version # output 속성으로 그대로 노출된다

  provisioner "local-exec" {
    command = "echo '[terraform_data] deploy ${self.input}' >> deploy.log"
  }
}

output "deployed_version" {
  value = terraform_data.deploy.output
}
