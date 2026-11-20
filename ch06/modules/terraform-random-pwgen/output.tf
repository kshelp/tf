output "id" {
  description = "자동 생성된 이름"
  value       = random_pet.name.id
}

output "pw" {
  description = "생성된 패스워드 (실습 편의를 위해 nonsensitive 처리)"
  value       = nonsensitive(random_password.password.result)
}
