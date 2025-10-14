data "http" "source_ip" {
  url = "http://checkip.amazonaws.com/"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.4.0"

  name = "${var.naming_prefix}-vpc"
  cidr = var.vpc_cidr

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = [cidrsubnet(var.vpc_cidr, 4, 0), cidrsubnet(var.vpc_cidr, 4, 1)]
  public_subnets  = [cidrsubnet(var.vpc_cidr, 4, 2), cidrsubnet(var.vpc_cidr, 4, 3)]

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_vpn_gateway = false
}

resource "aws_security_group" "litellm" {
  name        = "${var.naming_prefix}-litellm-sg"
  description = "security group for LiteLLM instances"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "litellm" {
  type              = "ingress"
  description       = "Allow inbound http access"
  from_port         = 3000
  to_port           = 3000
  protocol          = "tcp"
  cidr_blocks       = ["${chomp(data.http.source_ip.response_body)}/32"]
  security_group_id = aws_security_group.litellm.id
}

resource "aws_security_group_rule" "litellm_ssh" {
  type              = "ingress"
  description       = "Allow inbound ssh access"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["${chomp(data.http.source_ip.response_body)}/32"]
  security_group_id = aws_security_group.litellm.id
}

data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "random_id" "this" {
  byte_length = 4
}

resource "aws_key_pair" "litellm" {
  key_name   = "${var.naming_prefix}-litellm-key-${module.vpc.vpc_id}-${random_id.this.id}"
  public_key = var.ssh_public_key
}

module "litellm" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "6.1.1"
  name    = "${var.naming_prefix}-instance"

  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.litellm.id]
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  ami                         = data.aws_ssm_parameter.ubuntu_ami.value
  private_ip                  = cidrhost(var.vpc_cidr, 40)
  key_name                    = aws_key_pair.litellm.key_name

  user_data = templatefile("${path.module}/litellm.tpl",
    {
      litellm_port       = var.litellm_port
      litellm_image      = var.litellm_docker_image
      litellm_config_url = var.litellm_config_url
      litellm_api_key    = var.openai_api_key
  })
}

output "litellm_public_ip" {
  description = "Public IP of the LiteLLM instance"
  value       = "http://${module.litellm.public_ip}"
}
