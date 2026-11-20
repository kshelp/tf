# 10.2 프롬프트 예시

## 1. 코드 생성

```text
ap-northeast-2 리전에 VPC(10.0.0.0/16), 퍼블릭/프라이빗 서브넷 각 2개(AZ a, c),
NAT 게이트웨이 1개를 만드는 테라폼 코드를 작성해 줘.
- terraform >= 1.6, AWS provider ~> 6.0
- 변수는 variables.tf, 출력은 outputs.tf, 버전은 versions.tf로 분리
- 서브넷은 for_each로 만들고 CIDR은 cidrsubnet()으로 계산
- 모든 리소스에 environment 태그 추가 (provider default_tags 사용)
- 변수에는 description과 validation을 작성
- 코드만 출력하고, 마지막에 terraform validate로 확인할 점을 3줄로 요약
```

## 2. 코드 설명

```text
아래 테라폼 코드가 만드는 리소스와 리소스 간 의존 관계를 표로 설명해 줘.
비용이 발생하는 리소스와 보안상 주의할 설정도 따로 표시해 줘.
<코드 붙여넣기>
```

## 3. plan 결과 해석

```text
아래 terraform plan 결과에서 교체(-/+)되는 리소스와 그 원인(forces replacement 인수)을 찾아 줘.
교체를 피하려면 코드를 어떻게 바꿔야 하는지도 알려 줘.
<plan 출력 붙여넣기 - 계정 ID, IP 등은 마스킹>
```

## 4. 오류 분석

```text
terraform apply 중 아래 오류가 발생했다. 원인 후보를 가능성이 높은 순서로 3개 제시하고,
각각 확인할 명령과 수정 방법을 알려 줘. 사용 버전: terraform 1.17, aws provider 6.x
<오류 메시지 붙여넣기>
```

## 5. 리팩터링

```text
아래 코드에서 하드코딩된 값을 변수로 추출하고, aws_subnet 리소스 3개를 for_each 하나로 합쳐 줘.
기존 리소스가 재생성되지 않도록 필요한 moved 블록도 함께 작성해 줘.
<코드 붙여넣기>
```

## 6. 테스트 작성

```text
아래 모듈에 대해 terraform test 파일(tests/*.tftest.hcl)을 작성해 줘.
- mock_provider "aws" 사용 (자격증명 없이 실행)
- 서브넷 개수, CIDR, 태그를 assert로 검증
- 잘못된 environment 값에 대해 expect_failures 테스트 포함
<코드 붙여넣기>
```
