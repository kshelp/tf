# terraform-aws-collaboration (7.4 실습)

팀원이 같은 코드와 같은 HCP Terraform 워크스페이스(State)를 공유하며 작업하는 실습용 구성.

1. `main.tf`의 `cloud.organization`을 자신의 조직으로 변경
2. `terraform login` → `terraform init`
3. HCP Terraform 워크스페이스 변수에 `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`(Environment, Sensitive) 등록
4. 워크스페이스 변수 또는 `terraform.tfvars`에 `prefix` 지정
5. `terraform apply` → `app_url` 접속
6. 실습 후 `terraform destroy`
