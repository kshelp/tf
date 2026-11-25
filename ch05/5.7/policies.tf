# 환경별 정책 문서
#
#   tf-deployer-<env> (배포 역할) 권한
#     1. 5.6의 서비스(EC2/VPC, EKS, RDS, ElastiCache, ELB, Auto Scaling)를 지정 리전에서만 허용
#     2. Route 53 (글로벌 서비스라 리전 조건 없음)
#     3. IAM: 이름이 <env>-로 시작하는 역할·인스턴스 프로파일만, 권한 경계 tf-boundary-<env>를 붙일 때만 생성·변경
#     4. 자기 환경의 State 키만 읽기/쓰기
#     5. 가드레일(Deny): Environment 태그가 다른 환경 값인 리소스는 변경·조회 불가, 다른 환경 태그로 생성 불가
#
#   tf-boundary-<env> (권한 경계): 배포 역할이 만드는 IAM 역할(EKS 클러스터·노드, bastion)의 최대 권한.
#     경계가 없으면 배포 역할이 관리자 권한 역할을 만들어 EC2에 붙이는 식으로 권한을 넘어설 수 있다.

locals {
  regional_services = ["ec2", "eks", "rds", "elasticache", "elasticloadbalancing", "autoscaling"]

  service_linked_roles = [
    "eks.amazonaws.com",
    "eks-nodegroup.amazonaws.com",
    "elasticloadbalancing.amazonaws.com",
    "autoscaling.amazonaws.com",
    "rds.amazonaws.com",
    "elasticache.amazonaws.com",
  ]

  # 배포 역할과 권한 경계에 공통으로 넣는 가드레일
  guardrails = {
    for env in keys(var.environments) : env => [
      {
        # 다른 환경 태그가 붙은 리소스는 건드리지 않는다. 태그가 없는 리소스(AMI, 키 페어 등)는 대상이 아니다.
        Sid      = "DenyOtherEnvironmentResources"
        Effect   = "Deny"
        Action   = "*"
        Resource = "*"
        Condition = {
          StringNotEquals = { "aws:ResourceTag/Environment" = env }
          Null            = { "aws:ResourceTag/Environment" = "false" }
        }
      },
      {
        # 다른 환경 태그로 만들거나 태그를 바꾸지 못한다.
        Sid      = "DenyOtherEnvironmentTags"
        Effect   = "Deny"
        Action   = "*"
        Resource = "*"
        Condition = {
          StringNotEquals = { "aws:RequestTag/Environment" = env }
          Null            = { "aws:RequestTag/Environment" = "false" }
        }
      },
    ]
  }
}

# ---------- 배포 역할 권한 ----------
data "aws_iam_policy_document" "deployer" {
  for_each = var.environments

  statement {
    sid       = "RegionalServices"
    actions   = [for s in local.regional_services : "${s}:*"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.region]
    }
  }

  statement {
    sid       = "Route53"
    actions   = ["route53:*"]
    resources = ["*"]
  }

  statement {
    sid       = "ReadOnly"
    actions   = ["iam:Get*", "iam:List*", "kms:DescribeKey", "kms:ListAliases", "sts:GetCallerIdentity"]
    resources = ["*"]
  }

  statement {
    sid       = "ServiceLinkedRoles"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = local.service_linked_roles
    }
  }

  # 역할 생성·권한 변경은 권한 경계 tf-boundary-<env>가 붙어 있을 때만
  statement {
    sid = "EnvRolesWithBoundary"
    actions = [
      "iam:CreateRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePermissionsBoundary",
    ]
    resources = ["arn:${local.partition}:iam::${local.account_id}:role/${each.key}-*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [aws_iam_policy.boundary[each.key].arn]
    }
  }

  statement {
    sid = "EnvRolesManage"
    actions = [
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:UpdateRoleDescription",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
    ]
    resources = ["arn:${local.partition}:iam::${local.account_id}:role/${each.key}-*"]
  }

  statement {
    sid = "EnvInstanceProfiles"
    actions = [
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:UntagInstanceProfile",
    ]
    resources = ["arn:${local.partition}:iam::${local.account_id}:instance-profile/${each.key}-*"]
  }

  statement {
    sid       = "PassEnvRoles"
    actions   = ["iam:PassRole"]
    resources = ["arn:${local.partition}:iam::${local.account_id}:role/${each.key}-*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com", "eks.amazonaws.com"]
    }
  }

  statement {
    sid       = "StateList"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.state_key_prefix}/${each.key}/*"]
    }
  }

  statement {
    sid     = "StateObjects"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      "${aws_s3_bucket.state.arn}/${var.state_key_prefix}/${each.key}/terraform.tfstate",
      "${aws_s3_bucket.state.arn}/${var.state_key_prefix}/${each.key}/terraform.tfstate.tflock",
    ]
  }

  # 권한 경계를 떼어 내지 못하게 한다.
  statement {
    sid       = "DenyBoundaryRemoval"
    effect    = "Deny"
    actions   = ["iam:DeleteRolePermissionsBoundary"]
    resources = ["*"]
  }

  source_policy_documents = [jsonencode({ Version = "2012-10-17", Statement = local.guardrails[each.key] })]
}

# ---------- 권한 경계: 배포 역할이 만드는 IAM 역할의 상한 ----------
# 5.6의 역할에 붙는 정책(AmazonEKSClusterPolicy, AmazonEKSWorkerNodePolicy, AmazonEKS_CNI_Policy,
# AmazonEC2ContainerRegistryReadOnly, bastion의 eks:DescribeCluster)이 필요로 하는 범위
data "aws_iam_policy_document" "boundary" {
  for_each = var.environments

  statement {
    sid = "WorkloadServices"
    actions = [
      "ec2:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
      "eks:Describe*",
      "eks:List*",
      "eks-auth:AssumeRoleForPodIdentity",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:Describe*",
      "ecr:List*",
      "kms:CreateGrant",
      "kms:DescribeKey",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.region]
    }
  }

  statement {
    sid       = "ServiceLinkedRoles"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = local.service_linked_roles
    }
  }

  source_policy_documents = [jsonencode({ Version = "2012-10-17", Statement = local.guardrails[each.key] })]
}

resource "aws_iam_policy" "boundary" {
  for_each = var.environments

  name        = "tf-boundary-${each.key}"
  description = "Permissions boundary for IAM roles created by tf-deployer-${each.key}"
  policy      = data.aws_iam_policy_document.boundary[each.key].json
}

resource "aws_iam_policy" "deployer" {
  for_each = var.environments

  name        = "tf-deployer-${each.key}"
  description = "Deploy ch05/5.6 to the ${each.key} environment"
  policy      = data.aws_iam_policy_document.deployer[each.key].json
}
