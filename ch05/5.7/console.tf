# 콘솔 로그인 (실습용)
#   테라폼이 무작위 초기 암호를 만들고, 사용자는 첫 로그인 때 암호를 바꾼다.
#   주의: 초기 암호가 State(terraform.tfstate)에 평문으로 저장된다. 운영 환경에서는 pgp_key를 지정하거나
#         테라폼 밖에서 aws iam create-login-profile로 만든다.
#   로그인 직후에는 권한이 없으므로 역할 전환(Switch role)으로 tf-deployer-<env>를 맡는다.

resource "aws_iam_user_login_profile" "this" {
  for_each = var.console_access ? var.environments : {}

  user                    = aws_iam_user.this[each.key].name
  password_reset_required = true

  # 사용자가 암호를 바꿔도 테라폼이 다시 만들지 않도록 한다.
  lifecycle {
    ignore_changes = [password_length, password_reset_required, pgp_key]
  }
}

# 첫 로그인 때 암호를 바꾸려면 iam:ChangePassword 권한이 필요하다.
resource "aws_iam_user_policy_attachment" "change_password" {
  for_each = var.console_access ? var.environments : {}

  user       = aws_iam_user.this[each.key].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/IAMUserChangePassword"
}
