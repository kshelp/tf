# common

모든 환경이 공유하는 네트워크 기반(VPC, 프라이빗 서브넷)을 만드는 모듈.

## Usage

```hcl
module "common" {
  source = "../modules/common"
  prefix = "dev"
  tags   = { Environment = "dev" }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Resources

| Name | Type |
|------|------|
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_prefix"></a> [prefix](#input\_prefix) | 리소스 이름 접두사 (예: dev) | `string` | n/a | yes |
| <a name="input_private_subnets"></a> [private\_subnets](#input\_private\_subnets) | 가용 영역 => 프라이빗 서브넷 CIDR | `map(string)` | <pre>{<br/>  "ap-northeast-2a": "10.0.1.0/24",<br/>  "ap-northeast-2c": "10.0.2.0/24"<br/>}</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | 모든 리소스에 붙일 공통 태그 | `map(string)` | `{}` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | VPC CIDR 블록 | `string` | `"10.0.0.0/16"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | 프라이빗 서브넷 ID 목록 |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | VPC ID |
<!-- END_TF_DOCS -->
