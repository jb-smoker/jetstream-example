variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.1.0.0/24"
}

variable "naming_prefix" {
  description = "Prefix to use for resource names"
  type        = string
  default     = "litellm"
}

variable "ssh_public_key" {
  description = "SSH public key for accessing instances"
  type        = string
}

variable "openai_api_key" {
  description = "OpenAI API key for accessing the API"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 20
}

variable "litellm_port" {
  description = "Port on which LiteLLM will run"
  type        = number
  default     = 3000
}

variable "litellm_docker_image" {
  description = "Docker image for LiteLLM"
  type        = string
  default     = "ghcr.io/berriai/litellm:main-stable"
}

variable "litellm_config_url" {
  description = "URL to LiteLLM config file (leave empty to use defaults)"
  type        = string
  default     = ""
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access LiteLLM API"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Change this to restrict access
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Change this to restrict access
}
