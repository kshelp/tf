output "state_bucket" {
  description = "5.6 init 시 -backend-config=\"bucket=...\"에 넣는 값"
  value       = aws_s3_bucket.state.bucket
}

output "deployers" {
  description = "환경별 사용자·배포 역할·권한 경계"
  value = {
    for env, cfg in var.environments : env => {
      user        = aws_iam_user.this[env].name
      role_arn    = aws_iam_role.deployer[env].arn
      boundary    = aws_iam_policy.boundary[env].arn
      require_mfa = cfg.require_mfa
      admin       = cfg.admin
      state_key   = "${var.state_key_prefix}/${env}/terraform.tfstate"
    }
  }
}

output "aws_config" {
  description = "~/.aws/config에 추가할 프로필. 사용자 프로필(user1 등)의 액세스 키는 ~/.aws/credentials에 둔다"
  value = join("\n", [
    for env, cfg in var.environments : join("\n", compact([
      "[profile ${env}]",
      "role_arn         = ${aws_iam_role.deployer[env].arn}",
      "source_profile   = ${aws_iam_user.this[env].name}",
      "region           = ${var.region}",
      "duration_seconds = ${var.max_session_duration}",
      cfg.require_mfa ? "mfa_serial       = arn:${local.partition}:iam::${local.account_id}:mfa/<MFA 장치 이름>" : "",
      "",
    ]))
  ])
}

# ---------- 콘솔 로그인 ----------
output "account_id" {
  description = "IAM 사용자가 속한 AWS 계정 ID (콘솔 로그인 화면의 '계정 ID')"
  value       = local.account_id
}

output "console_signin_url" {
  description = "IAM 사용자 콘솔 로그인 주소"
  value       = "https://${local.account_id}.signin.aws.amazon.com/console"
}

output "console_switch_role_urls" {
  description = "로그인 후 배포 역할로 전환하는 주소"
  value = {
    for env in keys(var.environments) : env =>
    "https://signin.aws.amazon.com/switchrole?account=${local.account_id}&roleName=${aws_iam_role.deployer[env].name}&displayName=${env}"
  }
}

output "initial_passwords" {
  description = "사용자별 초기 암호 (첫 로그인 때 변경해야 함). 확인: terraform output -json initial_passwords"
  value       = { for k, v in aws_iam_user_login_profile.this : v.user => v.password }
  sensitive   = true
}
