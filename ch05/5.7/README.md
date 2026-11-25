# 5.7 환경별 배포 사용자 (IAM)

5.6(3계층 + EKS)을 **dev, stg, prod 환경별로** 배포할 IAM 사용자를 만든다. 한 AWS 계정 안에서 환경을 이름 접두사와 `Environment` 태그로 나눈다.

| 환경 | 사용자 | 배포 역할 | 권한 경계 | State 키 |
|---|---|---|---|---|
| dev | user1 (**AdministratorAccess**) | `tf-deployer-dev` | `tf-boundary-dev` | `ch05/5.6/dev/terraform.tfstate` |
| stg | user2 | `tf-deployer-stg` | `tf-boundary-stg` | `ch05/5.6/stg/terraform.tfstate` |
| prod | user3 | `tf-deployer-prod` | `tf-boundary-prod` | `ch05/5.6/prod/terraform.tfstate` |

## 구조

```
user1 ──AssumeRole──▶ tf-deployer-dev ──terraform apply──▶ 5.6 (env=dev)
 (자기 역할을 맡는 권한만 있음)   │
                                 ├─ EC2/VPC, EKS, RDS, ElastiCache, ELB, Auto Scaling: ap-northeast-2에서만
                                 ├─ Route 53
                                 ├─ IAM: dev-* 역할·인스턴스 프로파일만, 권한 경계 tf-boundary-dev를 붙일 때만
                                 ├─ S3: State 버킷의 ch05/5.6/dev/* 만
                                 └─ Deny: Environment 태그가 dev가 아닌 리소스, dev가 아닌 태그로 생성
```

| 파일 | 내용 |
|---|---|
| state.tf | State 버킷 `tfstate-<계정 ID>-<리전>` (버전 관리, 암호화, 퍼블릭 차단, TLS 강제) |
| policies.tf | 배포 역할 정책 `tf-deployer-<env>`, 권한 경계 `tf-boundary-<env>` |
| roles.tf | 배포 역할. 신뢰 정책은 해당 사용자만 허용(옵션: MFA 필수) |
| users.tf | user1~3과 자기 배포 역할을 맡는 인라인 정책, `admin = true`인 사용자(기본: user1)에 `AdministratorAccess` |
| console.tf | 콘솔 로그인 초기 암호(첫 로그인 시 변경), 암호 변경 권한 `IAMUserChangePassword` (실습용, `console_access = false`로 끌 수 있음) |

**권한 경계를 쓰는 이유**: 배포 역할은 5.6의 EKS·노드·bastion 역할을 만들어야 하므로 IAM 역할 생성 권한이 필요하다. 이때 제한이 없으면 관리자 권한을 가진 `dev-x` 역할을 만들어 EC2에 붙이는 방식으로 배포 역할 자신보다 큰 권한을 얻을 수 있다. 그래서 역할은 `tf-boundary-<env>`를 붙일 때만 만들 수 있게 하고, 경계를 떼어 내는 동작(`DeleteRolePermissionsBoundary`)은 막았다.

## user1 관리자 권한

기본값에서 dev 사용자 user1에는 AWS 관리형 정책 `AdministratorAccess`를 직접 붙인다(`environments`의 `admin = true`).

```hcl
environments = {
  dev  = { user = "user1", admin = true }   # false로 바꾸거나 빼면 관리자 권한 제거
  stg  = { user = "user2" }
  prod = { user = "user3" }
}
```

- 사용자 자격 증명에 직접 붙으므로 역할 전환 없이 `--profile user1`이나 콘솔 로그인 직후부터 계정 전체를 다룰 수 있다.
- 위 구조의 제한(리전, `<env>-*` IAM 이름, `Environment` 태그 가드레일, 권한 경계)은 **배포 역할에만** 적용된다. user1이 자기 자격 증명으로 작업하면 stg·prod 리소스와 5.7이 만든 사용자·역할·State 버킷도 변경할 수 있다.
- 5.6을 `AWS_PROFILE=dev`로 실행하면 지금처럼 배포 역할 `tf-deployer-dev` 권한으로 동작한다. user1 자격 증명으로 직접 실행하려면 `AWS_PROFILE=user1`로 두고 `TF_VAR_use_permissions_boundary`는 생략한다. 이때 EKS 클러스터 관리자는 user1이 된다.

## 5.6에서 바뀐 점

| 항목 | 내용 |
|---|---|
| `var.env` | `dev`(기본) / `stg` / `prod` |
| 이름 접두사 | `<env>-myeks`, `<env>-myeks-*-role`, `<env>-mysql`, `<env>-redis`, `<env>-web-lb` 등 계정에서 고유해야 하는 이름 |
| 태그 | 모든 리소스에 `Environment = <env>` (default_tags, 노드 시작 템플릿) |
| `var.use_permissions_boundary` | `true`면 5.6의 IAM 역할에 `tf-boundary-<env>`를 붙인다. **배포 역할로 실행할 때 필수** |
| backend | `backend "s3" {}` + `env/<env>.s3.tfbackend` (S3 네이티브 잠금 `use_lockfile`, Terraform 1.10 이상) |

VPC, 보안 그룹, Route 53 프라이빗 영역(`cloud.local`)은 환경마다 별도 VPC에 생기므로 이름을 바꾸지 않았다.

## 1. 관리자: 사용자·역할 만들기

IAM과 S3를 다룰 수 있는 관리자 자격 증명으로 실행한다.

```bash
cd ch05/5.7
terraform init
terraform apply
terraform output deployers
```

액세스 키는 State에 secret이 평문으로 남지 않도록 **테라폼 밖에서** 발급해 각 사용자에게 안전한 경로로 전달한다.

```bash
aws iam create-access-key --user-name user1   # user2, user3도 같은 방법으로
```

## 2. 사용자: AWS CLI 프로필 설정

`~/.aws/credentials` (발급받은 액세스 키):

```ini
[user1]
aws_access_key_id     = AKIA...
aws_secret_access_key = ...
```

`~/.aws/config` (`terraform output -raw aws_config` 출력에서 자기 환경 부분):

```ini
[profile dev]
role_arn         = arn:aws:iam::<계정 ID>:role/tf-deployer-dev
source_profile   = user1
region           = ap-northeast-2
duration_seconds = 14400
```

```bash
aws sts get-caller-identity --profile dev   # .../assumed-role/tf-deployer-dev/...
```

## 콘솔 로그인 (실습용)

5.7을 apply하면 사용자마다 무작위 초기 암호가 만들어진다. 관리자가 **계정 ID**와 **초기 암호**를 확인해 사용자에게 전달한다.

### 계정 ID 확인

IAM 사용자에게는 따로 계정 ID가 없다. user1~3은 5.7을 apply한 관리자와 **같은 AWS 계정**에 만들어지므로 그 계정의 ID를 쓴다.

```bash
# 방법 1: 테라폼 출력
terraform output -raw account_id                     # 123456789012

# 방법 2: AWS CLI (관리자 또는 사용자 자격 증명 어느 것이든 같은 값)
aws sts get-caller-identity --query Account --output text

# 방법 3: 사용자 ARN에서 확인 (관리자 자격 증명)
aws iam get-user --user-name user1 --query User.Arn --output text
# arn:aws:iam::123456789012:user/user1  ← 가운데 12자리가 계정 ID
```

### 초기 암호 확인

초기 암호는 `sensitive` 출력이라 `terraform output`만 실행하면 `<sensitive>`로 가려진다. `-json`을 붙여 확인한다.

```bash
terraform output -json initial_passwords             # {"user1":"...","user2":"...","user3":"..."}
terraform output -json initial_passwords | jq -r .user1
```

`jq`가 없으면:

```bash
terraform output -json initial_passwords | python3 -c 'import json,sys; print(json.load(sys.stdin)["user1"])'
```

### 한 번에 정리해 보기

```bash
ACCOUNT_ID=$(terraform output -raw account_id)
echo "로그인 주소: https://$ACCOUNT_ID.signin.aws.amazon.com/console"
echo "계정 ID   : $ACCOUNT_ID"
terraform output -json initial_passwords | jq -r 'to_entries[] | "\(.key)\t초기 암호: \(.value)"'
terraform output console_switch_role_urls
```

| 사용자에게 전달할 정보 | 확인 방법 | 예 |
|---|---|---|
| 로그인 주소 | `terraform output -raw console_signin_url` | `https://123456789012.signin.aws.amazon.com/console` |
| 계정 ID | `terraform output -raw account_id` | `123456789012` |
| IAM 사용자 이름 | `terraform output deployers` 의 `user` | `user1` |
| 초기 암호 | `terraform output -json initial_passwords` | 무작위 20자 |
| 역할 전환 주소 | `terraform output console_switch_role_urls` | `https://signin.aws.amazon.com/switchrole?account=...&roleName=tf-deployer-dev&displayName=dev` |

### 로그인 순서

1. 로그인 주소로 접속한다. 로그인 화면에서 **IAM 사용자**를 고르고 계정 ID를 입력해도 된다.
2. IAM 사용자 이름(`user1`)과 초기 암호로 로그인한 뒤 새 암호를 정한다(첫 로그인 때 변경 필수).
3. 로그인 직후에는 권한이 없다. 역할 전환 주소(`dev`)로 접속하거나 오른쪽 위 메뉴 **역할 전환**에서 계정 ID와 역할 `tf-deployer-dev`를 입력한다.
4. 리전을 **서울(ap-northeast-2)**로 맞춘다. 다른 리전과 다른 환경(`Environment` 태그) 리소스는 거부된다.

> **주의**: 초기 암호는 State(`terraform.tfstate`)에 평문으로 남는다. 실습용이므로 State 파일을 공유하지 않는다. 사용자가 암호를 바꾸면 `initial_passwords` 값으로는 더 이상 로그인할 수 없다(테라폼은 변경을 감지하지 않는다). 암호를 잊으면 관리자가 `terraform apply -replace='aws_iam_user_login_profile.this["dev"]'`로 새 초기 암호를 만든다. prod에 `require_mfa = true`를 쓰면 user3는 MFA로 로그인해야 역할 전환이 된다.

## 3. 사용자: 5.6 배포

```bash
cd ch05/5.6
export AWS_PROFILE=dev                 # kubernetes 프로바이더의 aws eks get-token도 같은 프로필을 쓴다
export TF_VAR_env=dev
export TF_VAR_use_permissions_boundary=true

terraform init -reconfigure \
  -backend-config=env/$TF_VAR_env.s3.tfbackend \
  -backend-config="bucket=<state_bucket 출력값>"
terraform apply
```

EKS 클러스터를 배포 역할이 만들므로 역할 `tf-deployer-dev`가 클러스터 관리자 권한을 받는다. `kubectl`도 같은 프로필로 쓴다.

환경을 바꿀 때는 `AWS_PROFILE`, `TF_VAR_env`를 바꾸고 `init -reconfigure`를 다시 실행한다. 환경마다 `.terraform` 디렉터리를 따로 두려면 `export TF_DATA_DIR=.terraform-$TF_VAR_env`를 함께 설정한다.

## 확인: 다른 환경은 막힌다

```bash
# user1(dev)이 prod 역할을 맡으려 하면 AccessDenied
aws sts assume-role --role-arn arn:aws:iam::<계정 ID>:role/tf-deployer-prod --role-session-name t --profile user1

# dev 역할로 prod State를 읽으면 AccessDenied
aws s3 cp s3://<버킷>/ch05/5.6/prod/terraform.tfstate - --profile dev

# dev 역할로 prod 클러스터 조회 → AccessDenied (Environment=prod 태그)
aws eks describe-cluster --name prod-myeks --profile dev

# 권한 경계 없이 실행하면 IAM 역할 생성에서 AccessDenied
TF_VAR_use_permissions_boundary=false terraform plan   # plan은 되지만 apply에서 iam:CreateRole 거부
```

## prod에 MFA 요구하기

`terraform.tfvars`:

```hcl
environments = {
  dev  = { user = "user1" }
  stg  = { user = "user2" }
  prod = { user = "user3", require_mfa = true }
}
```

관리자가 user3에게 가상 MFA 장치를 등록해 준다. 그다음 user3의 `[profile prod]`에 `mfa_serial = arn:aws:iam::<계정 ID>:mfa/<장치 이름>`을 추가하면 terraform 실행 시 MFA 코드를 묻는다.

## 한계 (한 계정 안에서 나누는 방식)

- 태그 가드레일은 **`Environment` 태그가 붙은 리소스만** 보호한다. EKS가 대신 만드는 리소스(노드 그룹의 ASG, ENI, 클러스터 보안 그룹)처럼 태그가 없는 리소스는 다른 환경 사용자도 변경할 수 있다.
- `ec2:Describe*` 같은 조회 API는 리소스 단위로 제한할 수 없어 다른 환경 리소스 목록이 보인다.
- 서비스 할당량(VPC 5개, EIP 5개 등)을 세 환경이 함께 쓴다. 세 환경을 동시에 띄우면 NAT용 EIP 6개가 필요해 기본 할당량(5개)을 넘는다.
- 환경을 완전히 격리하려면 AWS Organizations로 **환경별 계정**을 두고, 각 계정에 배포 역할을 만드는 방식이 표준이다.

## 삭제

5.6의 환경을 먼저 모두 destroy한 뒤 실행한다. State 버킷에 객체(버전 포함)가 남아 있으면 버킷 삭제가 실패한다.

```bash
terraform destroy
```
