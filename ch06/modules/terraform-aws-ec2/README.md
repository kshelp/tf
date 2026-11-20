# terraform-aws-ec2

최신 Amazon Linux 2023 AMI로 EC2 인스턴스 1대를 만드는 교육용 모듈.

```hcl
module "ec2" {
  source        = "../modules/terraform-aws-ec2"
  instance_type = "t3.micro"
  instance_name = "my-ec2"
}
```

입력·출력 표는 `terraform-docs markdown table .` 으로 생성한다(9.4절).
