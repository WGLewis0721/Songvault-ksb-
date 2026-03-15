# 🎵 SongVault — Highly Available Lyric & Setlist Manager on AWS

![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-623CE4?logo=terraform)
![AWS](https://img.shields.io/badge/AWS-ALB%20%7C%20ASG%20%7C%20RDS-FF9900?logo=amazon-aws)
![Python 3](https://img.shields.io/badge/Python-3.x-3776AB?logo=python)
![Flask](https://img.shields.io/badge/Flask-3.0.0-000000?logo=flask)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-336791?logo=postgresql)

---

> 🚀 **See what the finished app looks like before you deploy:** [**Live MVP Preview →**](https://wglewis0721.github.io/Songvault-ksb-/)
> *(Static demo — runs in your browser with no AWS account needed. Songs stored in localStorage.)*

---

> **New to GitHub?** No account yet? Start here → [GITHUB_SETUP.md](GITHUB_SETUP.md) — it walks you through creating an account, forking this repo, and cloning it to your computer before anything else.

---

## What This Proves (Resume-Focused)

- ✅ **Infrastructure as Code** — entire AWS environment provisioned with Terraform; destroy and rebuild in one command
- ✅ **High Availability** — ALB + ASG across two Availability Zones with automatic instance replacement
- ✅ **Least-privilege security** — chained security groups: internet → ALB → EC2 → RDS; database unreachable from internet
- ✅ **IAM best practices** — EC2 instances carry only CloudWatch + SSM permissions; no admin access
- ✅ **Zero-touch deployments** — user-data heredocs bootstrap the entire app on EC2 without manual SSH

---

## What SongVault Does

> **👀 Want to see it first?** Check out the [**live MVP preview**](https://wglewis0721.github.io/Songvault-ksb-/) — a static version of the app that runs entirely in your browser (no AWS needed). This is what your deployed app will look like when you're done.

- Store song lyrics with metadata: key, tempo, mood, and duration
- Build setlists with automatic total runtime calculation
- Works from any device — add songs from your phone before a gig
<img width="955" height="635" alt="Screenshot 2026-02-20 at 12 45 26 PM" src="https://github.com/user-attachments/assets/560c409f-0ee4-4423-b343-0c37996b77da" />

**App stack:**
- **Flask** — a lightweight Python web framework; handles HTTP requests and renders HTML pages
- **PostgreSQL** — relational database; stores songs and setlists
- **Gunicorn** — WSGI server; runs Flask in production on EC2

**AWS infrastructure (ALB → EC2 → RDS):**
- **ALB** routes internet traffic to app servers
- **ASG** manages EC2 instances; replaces failed ones automatically across two AZs
- **RDS** hosts PostgreSQL in a private subnet; never reachable from the internet

---

## Architecture

```
                        ┌─────────────────────────────────┐
                        │         AWS Cloud (VPC)          │
                        │                                  │
   Browser              │  PUBLIC SUBNETS                  │
   (anyone              │  ┌──────────┐  ┌──────────┐     │
    on the   ──────────►│  │  ALB     │  │  NAT GW  │     │
    internet)           │  │ AZ1+AZ2  │  │  (AZ1)   │     │
                        │  └────┬─────┘  └──────────┘     │
                        │       │                          │
                        │  PRIVATE SUBNETS                 │
                        │  ┌────▼─────┐  ┌──────────┐     │
                        │  │ EC2 App  │  │ EC2 App  │     │
                        │  │  (AZ1)   │  │  (AZ2)   │     │
                        │  └────┬─────┘  └────┬─────┘     │
                        │       └──────┬───────┘            │
                        │              │                    │
                        │       ┌──────▼──────┐             │
                        │       │  RDS Postgres│             │
                        │       │  (private)   │             │
                        │       └─────────────┘             │
                        └─────────────────────────────────┘
```

Traffic flows: Internet → ALB (public subnet) → EC2 app servers (private subnet) → RDS (private subnet).
The database is never reachable from the internet.

---

## Quick Start

> **New to GitHub?** Start with [GITHUB_SETUP.md](GITHUB_SETUP.md) first — it covers creating an account and getting the code onto your computer.
> **First time deploying?** Read [WALKTHROUGH.md](WALKTHROUGH.md) — it explains every step with expected output and common errors.

1. **Install prerequisites**: AWS CLI, Terraform ≥ 1.5.0, Git ([details in WALKTHROUGH.md](WALKTHROUGH.md#phase-1--install-the-tools))

2. **Clone the repo**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
   cd YOUR_REPO_NAME
   ```

3. **Set up variables**:
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   ```

4. **Edit `terraform.tfvars`** — set `db_password` to a real password (letters and numbers only, min 8 chars)

5. **Deploy**:
   ```bash
   terraform init && terraform plan && terraform apply
   ```

6. **Open the app** — copy the `alb_url` from the output and open it in your browser (wait ~3 min for instances to finish bootstrapping)

7. **Add a song and build a setlist** — you now have a live, highly available web application on AWS

---

## Stop the Bill

This project costs about $3–4 per day while it is running.
When you are done for the day, tear it down:

```bash
bash scripts/teardown.sh
```

Your data will be deleted but that is fine. It is Terraform.
Rebuild it fresh anytime:

```bash
cd terraform && terraform apply
```

Get in the habit of doing this every time. It takes 10 minutes to rebuild.
Forgetting costs $25–30 a week.

---

## Prove High Availability

This is the most important test. *"Companies pay cloud engineers to build this."*

1. Open your app in a browser tab — confirm it works.
2. AWS Console → EC2 → Instances → find a `songvault-app-server` → **Terminate** it.
3. Refresh your browser tab. **The app still works** — traffic routed to the other AZ instance.
4. EC2 → Auto Scaling Groups → `songvault-asg` → Activity tab — watch the ASG launch a replacement.

Total downtime: **0 minutes**. Recovery: fully automatic, ~5 minutes.

---

## Screenshot Checklist

- [ ] ALB URL open in browser showing the SongVault homepage
- [ ] Song added to library with all fields filled
- [ ] Setlist page with total runtime calculated
- [ ] ASG Activity tab showing automatic instance replacement

---

## Resume Bullets

Copy-paste these directly into your resume:

> • Designed and deployed a highly available AWS web application using Terraform, ALB, and Auto Scaling across two Availability Zones with automated failure recovery.

> • Built a Python/Flask application backed by RDS PostgreSQL in private subnets, applying least-privilege security group design to isolate all database access.

> • Automated Linux EC2 configuration using shell script heredocs and systemd, enabling zero-touch deployments with no manual SSH required.

---

## Cost Awareness ⚠️

| Resource | Approx Cost |
|----------|-------------|
| NAT Gateway | ~$0.045/hr + data transfer |
| RDS t3.micro | ~$0.017/hr |
| EC2 t3.micro (×2) | ~$0.021/hr each |
| ALB | ~$0.008/hr + LCU |
| **Total** | **~$2–4/day** |

The NAT Gateway is the biggest cost and runs 24/7 regardless of traffic.
**Run `terraform destroy` when done testing.**

---

## Cleanup

```bash
cd terraform
terraform destroy
# Type "yes" when prompted. This deletes everything and stops all charges.
```

---

## File Structure

```
.
├── README.md               ← You are here
├── GITHUB_SETUP.md         ← Start here if you're new to GitHub (no account yet)
├── WALKTHROUGH.md          ← Step-by-step guide for first-time AWS users
├── .gitignore              ← Excludes terraform.tfvars and secrets
├── index.html              ← GitHub Pages MVP — song library (static demo)
├── add_song.html           ← GitHub Pages MVP — add song form (static demo)
├── setlist.html            ← GitHub Pages MVP — setlist builder (static demo)
├── songvault-mvp.js        ← GitHub Pages MVP — shared data helpers (localStorage)
├── app/
│   ├── app.py              ← Flask application
│   ├── requirements.txt    ← Python dependencies
│   └── templates/
│       ├── index.html      ← Homepage — song library
│       ├── add_song.html   ← Add new song form
│       └── setlist.html    ← Setlist builder
├── terraform/
│   ├── main.tf             ← Terraform + AWS provider config
│   ├── variables.tf        ← Input variables
│   ├── outputs.tf          ← alb_url, rds_endpoint, asg_name, vpc_id
│   ├── networking.tf       ← VPC, subnets, IGW, NAT Gateway, route tables
│   ├── security.tf         ← ALB, app, and RDS security groups
│   ├── rds.tf              ← RDS PostgreSQL instance
│   ├── compute.tf          ← IAM role, Launch Template, Auto Scaling Group
│   ├── alb.tf              ← ALB, Target Group, Listener
│   └── terraform.tfvars.example  ← Safe template (copy → terraform.tfvars)
├── scripts/
│   └── user-data.sh        ← EC2 bootstrap script (heredocs, no git clone needed)
└── docs/
    ├── architecture.md         ← Full architecture explanation
    ├── networking-explained.md ← VPC, subnets, IGW, NAT, CIDR
    ├── autoscaling-explained.md← ASG, Launch Templates, health checks
    └── how-rds-works.md        ← RDS, private subnets, connection strings
```
