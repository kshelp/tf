# 플랫폼 팀이 HCP Terraform 자체(프로젝트·워크스페이스·변수·팀 권한)를 코드로 관리한다.
terraform {
  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.70"
    }
  }
}

# 인증: TFE_TOKEN 환경 변수 또는 terraform login 토큰
provider "tfe" {
  organization = var.organization
}

variable "organization" {
  type = string
}

variable "teams" {
  type        = map(string)
  description = "팀 이름 => 사용할 환경"
  default = {
    "team-a" = "dev"
    "team-b" = "dev"
  }
}

resource "tfe_project" "self_service" {
  name = "self-service"
}

# 팀마다 워크스페이스를 하나씩 발급한다.
resource "tfe_workspace" "team" {
  for_each = var.teams

  name       = "${each.key}-${each.value}"
  project_id = tfe_project.self_service.id
  tag_names  = ["self-service", each.value]
}

resource "tfe_variable" "environment" {
  for_each = var.teams

  workspace_id = tfe_workspace.team[each.key].id
  key          = "environment"
  value        = each.value
  category     = "terraform"
}

output "workspace_ids" {
  value = { for k, w in tfe_workspace.team : k => w.id }
}
