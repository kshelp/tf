# 환경별 배포 역할: tf-deployer-<env>
#   이름이 <env>-로 시작하지 않으므로 배포 역할 자신은 IAM 정책의 <env>-* 범위 밖이다(스스로 권한을 바꿀 수 없다).
#   5.6의 EKS 클러스터는 이 역할로 만들어지므로 역할이 클러스터 관리자 권한을 받는다(bootstrap_cluster_creator_admin_permissions).

data "aws_iam_policy_document" "deployer_trust" {
  for_each = var.environments

  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.this[each.key].arn]
    }

    dynamic "condition" {
      for_each = each.value.require_mfa ? [1] : []
      content {
        test     = "Bool"
        variable = "aws:MultiFactorAuthPresent"
        values   = ["true"]
      }
    }
  }
}

resource "aws_iam_role" "deployer" {
  for_each = var.environments

  name                 = "tf-deployer-${each.key}"
  description          = "Terraform deployer for ch05/5.6 (${each.key})"
  assume_role_policy   = data.aws_iam_policy_document.deployer_trust[each.key].json
  max_session_duration = var.max_session_duration
  tags                 = { Environment = each.key }
}

resource "aws_iam_role_policy_attachment" "deployer" {
  for_each = var.environments

  role       = aws_iam_role.deployer[each.key].name
  policy_arn = aws_iam_policy.deployer[each.key].arn
}
