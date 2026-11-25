# 배포 사용자: 자기 환경의 배포 역할을 맡는(AssumeRole) 권한만 가진다.
# 액세스 키는 State에 secret이 평문으로 남지 않도록 테라폼 밖에서 발급한다(README 참고).
# 콘솔 로그인 암호는 실습 편의를 위해 테라폼으로 만든다(console.tf).

resource "aws_iam_user" "this" {
  for_each = var.environments

  name          = each.value.user
  force_destroy = true # 테라폼 밖에서 만든 액세스 키·MFA가 있어도 destroy 가능
  tags          = { Environment = each.key }
}

resource "aws_iam_user_policy" "assume_deployer" {
  for_each = var.environments

  name = "assume-tf-deployer-${each.key}"
  user = aws_iam_user.this[each.key].name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sts:AssumeRole", "sts:TagSession"]
      Resource = aws_iam_role.deployer[each.key].arn
    }]
  })
}

# 관리자 권한 (environments의 admin = true인 사용자, 기본값: user1)
#   사용자 자격 증명에 직접 붙으므로 배포 역할의 리전·IAM 이름·Environment 태그 제한과 권한 경계가 적용되지 않는다.
#   다른 환경(stg, prod) 리소스와 이 코드가 만든 사용자·역할·State 버킷도 변경할 수 있다.
resource "aws_iam_user_policy_attachment" "admin" {
  for_each = { for env, cfg in var.environments : env => cfg if cfg.admin }

  user       = aws_iam_user.this[each.key].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AdministratorAccess"
}
