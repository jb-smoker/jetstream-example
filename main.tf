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
  type        = "ingress"
  description = "Allow inbound http access"
  from_port   = 3000
  to_port     = 3000
  protocol    = "tcp"
  #   cidr_blocks       = ["10.0.0.0/8", "192.168.0.0/16", "172.16.0.0/12"]
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

# module "dashboard" {
#   source  = "terraform-aws-modules/ec2-instance/aws"
#   version = "5.8.0"
#   name    = "aws-dashboard"

#   instance_type               = "t3.micro"
#   vpc_security_group_ids      = [aws_security_group.dashboard.id]
#   subnet_id                   = module.spoke_aws.vpc.public_subnets[0].subnet_id
#   ami                         = data.aws_ssm_parameter.ubuntu_ami.value
#   associate_public_ip_address = true
#   key_name                    = aws_key_pair.dashboard_ssh_key.key_name

#   user_data = templatefile("${path.module}/templates/dashboard.tpl",
#     {
#       gatus = "10.0.1.10"
#   })
#   depends_on = [module.spoke_aws, aviatrix_distributed_firewalling_policy_list.dcf]
# }


# # Security Group
# resource "aws_security_group" "litellm" {
#   name        = "litellm-sg"
#   description = "Security group for LiteLLM container"

#   ingress {
#     from_port   = 4000
#     to_port     = 4000
#     protocol    = "tcp"
#     cidr_blocks = var.allowed_cidr_blocks
#   }

#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = var.ssh_cidr_blocks
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "litellm-sg"
#   }
# }

# # EC2 Instance
# resource "aws_instance" "litellm" {
#   ami                    = data.aws_ami.ubuntu.id
#   instance_type          = var.instance_type
#   vpc_security_group_ids = [aws_security_group.litellm.id]
#   user_data = base64encode(templatefile("${path.module}/litellm.tpl", {
#     litellm_port       = var.litellm_port
#     litellm_image      = var.litellm_docker_image
#     litellm_config_url = var.litellm_config_url
#   }))

#   root_block_device {
#     volume_type           = "gp3"
#     volume_size           = var.root_volume_size
#     delete_on_termination = true
#   }

#   tags = {
#     Name = "litellm-server"
#   }
# }

# # Get the latest Ubuntu 22.04 LTS AMI
# data "aws_ami" "ubuntu" {
#   most_recent = true
#   owners      = ["099720109477"] # Canonical

#   filter {
#     name   = "name"
#     values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
#   }

#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }
# }

# # Outputs
# output "litellm_public_ip" {
#   description = "Public IP of the LiteLLM instance"
#   value       = aws_instance.litellm.public_ip
# }

# output "litellm_private_ip" {
#   description = "Private IP of the LiteLLM instance"
#   value       = aws_instance.litellm.private_ip
# }

# output "litellm_url" {
#   description = "URL to access LiteLLM API"
#   value       = "http://${aws_instance.litellm.public_ip}:${var.litellm_port}"
# }
