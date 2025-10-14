# jetstream-example: LiteLLM Proxy on AWS with Terraform

## Project Requirements

Deploy a secure, scalable LLM Gateway using LiteLLM, exposed via a proxy, deployed on cloud infrastructure using Terraform, and with all secrets (e.g., API keys) managed through GitHub Secrets.

### Cloud Deployment

- Deploy the LiteLLM container on a public cloud provider of your choice: AWS (preferred) or GCP
- Use Terraform to provision:
- The compute resource (e.g., AWS EC2, ECS, or GCP Compute Instance)
- Associated networking infrastructure (VPC, subnet, public IP etc.)

### LiteLLM Setup

- Run LiteLLM in a Docker container.
- Ensure the container exposes the proxy API on port 3000 (default).

### Public Access

- The LiteLLM proxy should be accessible via a public endpoint (public IP or domain).
- Include an example cURL request in the README to demonstrate how to access the proxy.

### Secrets Management

- Store sensitive information using GitHub Secrets.
- Pass these secrets securely to the container (via CI/CD or instance environment).
- Do not hardcode or commit any secrets to the repo.

### Network Security

- Configure firewall rules to restrict inbound access:
- Use AWS Security Groups or GCP Firewall Rules.
- Only allow traffic on required ports (e.g., 3000).

### Known Issues/Gaps

1. LiteLLM currently has no models configured. Research required for configuration to achieve end-to-end query/response
2. The LiteLLM API is exposed via http on port 3000, not meeting the standards of "secure" set in the requirements. Solutions include:
   1. Adding a reverse proxy or AWS ALB to implement tls termination.
   2. Adding a WAF to mitigate common attacks.
3. Scaling has been deemed out of scope for this exercise.

## Overview

This repository contains Terraform configuration to deploy a LiteLLM proxy container on an AWS EC2 instance within a VPC, with automated deployment via GitHub Actions. The infrastructure includes:

- **VPC with Public/Private Subnets** - Two availability zones across public and private subnets
- **NAT Gateway** - Single NAT gateway in public subnet for outbound traffic for private subnets
- **Security Groups** - Restrictive ingress rules for API (port 3000)
- **EC2 Instance** - Ubuntu 24.04 LTS with Docker and LiteLLM running
- **Automated Deployment** - GitHub Actions workflow, leveraging HCP Terraform for Terraform plan and apply

## Quick Start

### 1. Prerequisites

- AWS Account with EC2, VPC, and IAM permissions
- GitHub account with repository access
- SSH public key for EC2 access
- OpenAI API key (or compatible API key for LiteLLM)
- HCP Terraform account and workspace configured with API access

### 2. Configure GitHub Secrets

Add the following secrets to your GitHub repository (Settings → Secrets and variables → Actions):

```terraform
TF_API_TOKEN              # Terraform Cloud API token
AWS_ACCESS_KEY_ID         # AWS access key
AWS_SECRET_ACCESS_KEY     # AWS secret access key
SSH_PUBLIC_KEY            # Your SSH public key
OPENAI_API_KEY            # OpenAI API key for LiteLLM
```

To generate and add secrets via GitHub CLI:

```bash
gh secret set TF_API_TOKEN --body "your-terraform-token"
gh secret set AWS_ACCESS_KEY_ID --body "your-aws-key"
gh secret set AWS_SECRET_ACCESS_KEY --body "your-aws-secret"
gh secret set SSH_PUBLIC_KEY --body "$(cat ~/.ssh/id_rsa.pub)"
gh secret set OPENAI_API_KEY --body "your-openai-key"
```

### 3. Update Terraform Variables

Create a `terraform.tfvars` file or update variables in your Terraform workspace:

```hcl
aws_region         = "us-west-2"           # Change as needed
ssh_public_key     = "<your-public-key>"   # Set via GitHub Secret
openai_api_key     = "<your-api-key>"      # Set via GitHub Secret
naming_prefix      = "litellm"
instance_type      = "t3.micro"
vpc_cidr           = "10.1.0.0/24"
litellm_port       = 3000
```

### 4. Deploy

Push to main branch to trigger automatic deployment:

```bash
git add .
git commit -m "Deploy LiteLLM infrastructure"
git push origin main
```

The GitHub Actions workflow will:

1. Check Terraform formatting
2. Initialize Terraform
3. Generate and apply infrastructure changes
4. Output the public IP of your LiteLLM instance

## Infrastructure

### AWS Architecture

```
┌─────────────────────────────────────────────────────┐
│                        VPC                          │
│                    (10.1.0.0/24)                    │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Public Subnets              Private Subnets        │
│  ┌──────────────┐            ┌──────────────┐       │
│  │ EC2 Instance │            │ NAT Gateway  │       │
│  │ (LiteLLM)    │────┐       └──────────────┘       │
│  │ Port 3000    │    │              ▲               │
│  └──────────────┘    └──────────────┘               │
│         ▲                                           │
│         │ Internet Gateway                          │
└─────────┼───────────────────────────────────────────┘
          │
      ┌───┴─────┐
      │ Internet│
      └─────────┘
```

### Resources Provisioned

**VPC Module** (terraform-aws-modules/vpc/aws v6.4.0)

- CIDR: 10.1.0.0/24
- Public subnets: 10.1.0.128/25 (us-west-2a), 10.1.0.0/25 (us-west-2b)
- Private subnets: 10.1.0.144/28 (us-west-2a), 10.1.0.160/28 (us-west-2b)
- Single NAT Gateway

**Security Group** (`litellm-sg`)

- **Ingress**: Port 3000 (API access)
- **Source**: 0.0.0.0/0
- **Egress**: All outbound traffic unrestricted

**EC2 Instance** (terraform-aws-modules/ec2-instance/aws v6.1.1)

- AMI: Ubuntu 24.04 LTS (latest)
- Instance Type: t3.micro (default, configurable)
- Private IP: 10.1.0.40 (within VPC CIDR)
- Public IP: Automatically assigned
- SSH Key: Dynamically generated with random suffix
- User Data: Installs Docker and runs LiteLLM container

## GitHub Actions Workflow

The `terraform.yml` workflow automates infrastructure deployment:

### Trigger Events

- **Push to main** - Triggers `terraform apply` for deployment
- **Pull Request** - Triggers `terraform plan` for validation

### Workflow Steps

**1. Checkout**

- Retrieves repository code

**2. Setup Terraform**

- Configures Terraform Cloud authentication using `TF_API_TOKEN` secret
- Sets AWS credentials from GitHub Secrets

**3. Terraform Format Check**

- Validates Terraform code formatting
- Fails if code doesn't match Terraform standards

**4. Terraform Init**

- Initializes Terraform
- Connects to Terraform Cloud workspace: `jb-smoker/jetstream`

**5. Terraform Plan** (Pull Request Only)

- Generates infrastructure change plan
- Passes `ssh_public_key` and `openai_api_key` from GitHub Secrets
- Posts plan output as PR comment for review

**6. PR Comment Update** (Pull Request Only)

- Posts formatted plan results on PR
- Shows Terraform format, init, and plan status
- Allows reviewers to validate changes before merge

**7. Plan Status Check**

- Exits with failure if plan had errors
- Prevents accidental merges of invalid configurations

**8. Terraform Apply** (Main Branch Push Only)

- Auto-approves and applies infrastructure changes
- Only runs on pushes to main branch
- Uses secrets for SSH key and API key variables

### Required Secrets

| Secret                  | Purpose                                       |
| ----------------------- | --------------------------------------------- |
| `TF_API_TOKEN`          | Authenticate with Terraform Cloud workspace   |
| `AWS_ACCESS_KEY_ID`     | AWS authentication                            |
| `AWS_SECRET_ACCESS_KEY` | AWS authentication                            |
| `SSH_PUBLIC_KEY`        | EC2 key pair creation                         |
| `OPENAI_API_KEY`        | LiteLLM API credentials (passed to container) |

## Accessing LiteLLM

After deployment, retrieve the public IP:

```bash
# From GitHub Actions output or via Terraform
terraform output litellm_public_ip
```

### Health Check

```bash
curl -X GET http://<PUBLIC_IP>:3000/health
```

### Example API Requests

**List Available Models**

```bash
curl -X GET http://<PUBLIC_IP>:3000/models \
  -H "Authorization: Bearer sk-<your-key>"
```

**Chat Completion**

```bash
curl -X POST http://<PUBLIC_IP>:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-<your-key>" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [
      {"role": "user", "content": "Hello, LiteLLM!"}
    ]
  }'
```

**Streaming Response**

```bash
curl -X POST http://<PUBLIC_IP>:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-<your-key>" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [
      {"role": "user", "content": "Tell me a story"}
    ],
    "stream": true
  }'
```

## Configuration

### Terraform Variables

**Required**

- `ssh_public_key` - Your SSH public key (passed via GitHub Secret)
- `openai_api_key` - API key for LiteLLM (passed via GitHub Secret)

**Optional with Defaults**

| Variable               | Default                             | Description                |
| ---------------------- | ----------------------------------- | -------------------------- |
| `aws_region`           | us-west-2                           | AWS region for deployment  |
| `vpc_cidr`             | 10.1.0.0/24                         | VPC CIDR block             |
| `naming_prefix`        | litellm                             | Prefix for resource names  |
| `instance_type`        | t3.micro                            | EC2 instance type          |
| `root_volume_size`     | 20                                  | Root volume size in GB     |
| `litellm_port`         | 3000                                | Port for LiteLLM API       |
| `litellm_docker_image` | ghcr.io/berriai/litellm:main-stable | LiteLLM Docker image       |
| `litellm_config_url`   | (empty)                             | URL to LiteLLM config file |
| `allowed_cidr_blocks`  | 0.0.0.0/0                           | CIDR blocks for API access |

## LiteLLM Container

The container is provisioned via user data script (`litellm.tpl`):

**Installation**

- Updates Ubuntu 24.04 system
- Installs Docker with GPG key verification
- Adds ubuntu user to docker group

**Container Configuration**

```bash
docker run -d \
  --name litellm \
  --restart unless-stopped \
  --platform linux/amd64 \
  -p 3000:4000 \
  -e OPENAI_API_KEY=${litellm_api_key} \
  ghcr.io/berriai/litellm:main-stable
```

**Health Verification**

- Waits 5 seconds for container startup
- Checks if container is running
- Logs errors if startup fails

### Environment Variables

- `OPENAI_API_KEY` - Passed from Terraform variable via GitHub Secret
- Container runs on internal port 4000, exposed as 3000 on host

## Project Structure

```
jetstream-example/
├── README.md                     # This file
├── LICENSE                       # MIT License
├── main.tf                       # VPC, security groups, EC2 instance
├── provider.tf                   # AWS provider and Terraform Cloud config
├── variables.tf                  # Variable definitions
├── litellm.tpl                   # User data script for EC2 bootstrap
└── .github/
    └── workflows/
        └── terraform.yml         # GitHub Actions workflow
```

## Contributing

1. Create a feature branch: `git switch -c feature/my-feature`
2. Make changes and test
3. Push and open a PR
4. GitHub Actions automatically runs `terraform plan`
5. After approval and merge, `terraform apply` runs automatically

## License

MIT License - See LICENSE file for details

## References

- [LiteLLM Documentation](https://docs.litellm.ai/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terraform Cloud](https://www.terraform.io/cloud)
- [AWS EC2 Security Groups](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html)
