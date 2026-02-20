# SongVault 🎵

![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-623CE4?logo=terraform)
![AWS](https://img.shields.io/badge/AWS-EC2%20%7C%20ALB%20%7C%20RDS-FF9900?logo=amazon-aws)
![Python](https://img.shields.io/badge/Python-3.x%20Flask-3776AB?logo=python)

SongVault is a Flask web application for managing song lyrics and setlists,
deployed on AWS with high availability using an **Application Load Balancer**,
**Auto Scaling Group**, and **RDS PostgreSQL** — fully automated with Terraform.

---

## What This Project Proves

This project demonstrates production-pattern AWS architecture skills:

- ✅ **Infrastructure as Code** with Terraform (VPC, subnets, IGW, NAT, ASG, ALB, RDS)
- ✅ **High Availability** across two Availability Zones
- ✅ **Least-privilege security** with chained security groups (internet → ALB → EC2 → RDS)
- ✅ **Automated instance bootstrap** via user-data script and systemd
- ✅ **Secrets management** via environment variables (never in source code)
- ✅ **Managed database** with RDS PostgreSQL in private subnets

---

## Architecture Diagram

```
  Internet
     │
     │  HTTP :80
     ▼
┌──────────────────────────────────────────┐
│             AWS VPC (10.0.0.0/16)        │
│                                          │
│  Public Subnets (AZ-1, AZ-2)            │
│  ┌────────────────────────────────┐      │
│  │   Application Load Balancer    │      │
│  │          (ALB)                 │      │
│  └──────────────┬─────────────────┘      │
│                 │ HTTP :8080             │
│  Private Subnets (AZ-1, AZ-2)           │
│  ┌──────────────┴─────────────────┐      │
│  │      Auto Scaling Group        │      │
│  │  ┌──────────┐  ┌──────────┐   │      │
│  │  │ EC2 AZ-1 │  │ EC2 AZ-2 │   │      │
│  │  │ Flask    │  │ Flask    │   │      │
│  │  └────┬─────┘  └────┬─────┘   │      │
│  └───────┼──────────────┼─────────┘      │
│          │  TCP :5432   │               │
│  ┌───────┴──────────────┴─────────┐      │
│  │     RDS PostgreSQL (private)   │      │
│  └────────────────────────────────┘      │
└──────────────────────────────────────────┘
```

---

## Prerequisites

Before deploying SongVault you need the following tools installed:

| Tool | Install Guide |
|------|--------------|
| **AWS CLI** | https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html |
| **Terraform** ≥ 1.5.0 | https://developer.hashicorp.com/terraform/install |
| **Git** | https://git-scm.com/downloads |
| **VS Code** (optional but recommended) | https://code.visualstudio.com/ |

Configure your AWS credentials before running Terraform:

```bash
aws configure
# Enter: AWS Access Key ID, Secret Access Key, default region (us-east-1), output format (json)
```

---

## Deployment Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/YOUR_GITHUB_USERNAME/YOUR_REPO_NAME.git
cd YOUR_REPO_NAME
```

### 2. Update the GitHub Repo URL in user-data.sh

Open `scripts/user-data.sh` and replace `YOUR_GITHUB_REPO_URL` with your
actual repository URL:

```bash
# Before:
git clone YOUR_GITHUB_REPO_URL /opt/songvault-repo

# After:
git clone https://github.com/YOUR_USERNAME/songvault-ha-webapp.git /opt/songvault-repo
```

### 3. Initialise Terraform

```bash
cd terraform
terraform init
```

This downloads the AWS provider plugin (~50 MB). You should see:
`Terraform has been successfully initialized!`

### 4. Set a Real Database Password

Edit `terraform/terraform.tfvars`:

```hcl
db_password = "MySecurePassword123!"  # use a real strong password
```

> ⚠️ **Never commit this file with a real password to a public repository.**
> Add `terraform.tfvars` to `.gitignore` if your repo is public.

### 5. Preview the Plan

```bash
terraform plan
```

Review the output — you should see ~20 resources to be created.

### 6. Deploy

```bash
terraform apply
```

Type `yes` when prompted. Deployment takes about **5–10 minutes** (RDS takes
the longest).

When complete, Terraform prints:

```
Outputs:

alb_dns_name = "http://songvault-alb-1234567890.us-east-1.elb.amazonaws.com"
rds_endpoint = "songvault-db.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com"
asg_name     = "songvault-asg"
```

### 7. Open the App

Copy the `alb_dns_name` URL and open it in your browser. The SongVault app
should load within 3–5 minutes of the instances passing health checks.

---

## Prove High Availability

Want to see the ASG self-healing in action? Follow these steps:

1. **Find a running instance** in the AWS Console → EC2 → Instances.
   Look for instances named `songvault-app`.

2. **Terminate one instance** manually:
   - Select the instance → Actions → Instance State → Terminate.
   - Confirm termination.

3. **Watch the ASG react**:
   ```bash
   aws autoscaling describe-auto-scaling-groups \
     --auto-scaling-group-names songvault-asg \
     --query 'AutoScalingGroups[0].Instances[*].{ID:InstanceId,State:LifecycleState,Health:HealthStatus}'
   ```

4. **Within 5 minutes**, the ASG launches a replacement instance. The app
   continues running from the healthy instance in the other AZ.

5. Refresh the ALB URL during the termination — traffic flows to the healthy
   instance with no downtime.

---

## Screenshots

> Replace these placeholder blocks with real screenshots after deploying.

**Screenshot 1 — SongVault Homepage**
```
[ Add screenshot of http://<alb-dns>/  here ]
```

**Screenshot 2 — Add Song Form**
```
[ Add screenshot of http://<alb-dns>/add  here ]
```

**Screenshot 3 — Setlist Page**
```
[ Add screenshot of http://<alb-dns>/setlist  here ]
```

**Screenshot 4 — AWS Console showing ASG with 2 healthy instances**
```
[ Add screenshot of EC2 → Auto Scaling Groups → songvault-asg  here ]
```

---

## Resume Bullets

Copy-paste these bullets directly into your resume:

- **Designed and deployed a high-availability Flask web application on AWS** using Terraform, with an Application Load Balancer routing traffic across an Auto Scaling Group (min 2, max 4) spread across two Availability Zones, achieving zero-downtime instance replacement.

- **Architected a least-privilege network security model** using chained VPC Security Groups: internet traffic is restricted to the ALB, the ALB forwards only to EC2 app servers, and EC2 can only connect to RDS PostgreSQL — the database is unreachable from the internet.

- **Automated full infrastructure provisioning with Terraform** (VPC, subnets, IGW, NAT Gateway, RDS, ASG, ALB) and instance bootstrap via a user-data script that installs dependencies, injects secrets via environment variables, and registers the app as a systemd service.

---

## Cleanup

To destroy all AWS resources and stop incurring charges:

```bash
cd terraform
terraform destroy
```

Type `yes` when prompted.

> 💰 **Cost Warning**: Running this stack costs approximately **$3–5 per day**
> primarily due to the NAT Gateway (~$1.10/day) and RDS instance (~$0.017/hr).
> Always run `terraform destroy` when you're done testing.

---

## File Structure

```
songvault-ha-webapp/
├── README.md
├── app/
│   ├── app.py                  # Flask application
│   ├── requirements.txt        # Python dependencies
│   └── templates/
│       ├── index.html          # Homepage — song list
│       ├── add_song.html       # Add new song form
│       └── setlist.html        # Setlist manager
├── terraform/
│   ├── main.tf                 # Terraform + provider config
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # ALB URL, RDS endpoint, ASG name
│   ├── vpc.tf                  # VPC, subnets, IGW, NAT, route tables
│   ├── security_groups.tf      # ALB, app, and RDS security groups
│   ├── rds.tf                  # RDS PostgreSQL instance
│   ├── launch_template.tf      # EC2 Launch Template (AMI + user-data)
│   ├── asg.tf                  # Auto Scaling Group
│   ├── alb.tf                  # ALB, Target Group, Listener
│   └── terraform.tfvars        # Variable overrides (⚠️ don't commit passwords)
├── scripts/
│   └── user-data.sh            # EC2 bootstrap script
└── docs/
    ├── architecture.md         # Full architecture explanation + diagram
    ├── networking-explained.md # VPC, subnets, IGW, NAT, CIDR
    ├── autoscaling-explained.md# ASG, Launch Templates, health checks
    └── how-rds-works.md        # RDS, private subnets, connection strings
```

