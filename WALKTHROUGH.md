# SongVault — Complete Step-by-Step Walkthrough
# For engineers who are new to AWS and Terraform

This guide walks you through every step of deploying SongVault. Each step explains
what you're doing and why. If a command produces output, I'll show you what it should
look like. If something can go wrong, I'll tell you what to watch for.

---

## Phase 0 — Understanding What You Are Building (read before touching a terminal)

### BEFORE YOU SPEND A DOLLAR — READ THIS

This project costs real money while it is running. About $3–4 a day.
That does not sound like much but if you build it on a Monday and
forget about it, by Sunday you have a $25 bill for nothing.

The rule is simple: when you are done for the day, run:

```bash
bash scripts/teardown.sh
```

It deletes everything. Your data goes with it. That is fine.
This is infrastructure as code. You can rebuild the whole thing
in 10 minutes anytime you want with one command:

```bash
cd terraform && terraform apply
```

This is actually the point. The fact that you can destroy and
rebuild your entire cloud environment in minutes is exactly what
makes Terraform valuable. You are not losing anything.
You are proving the skill.

---

**The app:**
- SongVault stores song lyrics, metadata (key, tempo, mood), and builds setlists with runtime totals
- Built with **Flask** (a lightweight Python web framework), **PostgreSQL** (database), and **Gunicorn** (production server)
- Flask receives HTTP requests, queries PostgreSQL, and returns HTML pages — that's the full app

**AWS services:**
- **VPC** — your private isolated network in AWS
- **ALB** — public entry point; distributes traffic to your EC2 servers
- **ASG** — manages EC2 instances; replaces failed ones automatically
- **RDS** — managed PostgreSQL; AWS handles the database server, you just connect to it
- **NAT Gateway** — lets private EC2 instances download packages without exposing them to the internet

**Terraform** — turns `.tf` config files into real AWS infrastructure; reproducible with one command

---

## Phase 1 — Install the Tools

### AWS CLI

The AWS CLI is a command-line tool that lets Terraform talk to your AWS account.

**macOS:**
```bash
brew install awscli
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get install awscli -y
```

**Verify:**
```bash
aws --version
```

**Expected output:**
```
aws-cli/2.x.x Python/3.x.x Linux/... botocore/2.x.x
```

---

### Terraform

Terraform is the tool that reads your `.tf` files and builds AWS infrastructure.

**macOS:**
```bash
brew tap hashicorp/tap && brew install hashicorp/tap/terraform
```

**Linux:**
```bash
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install terraform
```

**Verify:**
```bash
terraform -version
```

**Expected output:**
```
Terraform v1.x.x
on linux_amd64
```

> ⚠️ If you see version 0.x.x, you have an old version. Follow the install steps again.

---

### Git

Git is how you manage and share your code. Most systems already have it.

**Verify:**
```bash
git --version
```

**Expected output:**
```
git version 2.x.x
```

---

## Phase 2 — Connect Your AWS Account

Terraform needs credentials to talk to AWS on your behalf. We configure these
with the AWS CLI.

**Where to get access keys:**
1. Log into the AWS Console at https://console.aws.amazon.com
2. Click your name in the top right → Security Credentials
3. Scroll to "Access keys" → Create access key
4. Copy both the Access Key ID and Secret Access Key (you only see the secret once)

**Configure the CLI:**
```bash
aws configure
```

**What you'll be asked:**
```
AWS Access Key ID [None]:        <paste your access key>
AWS Secret Access Key [None]:    <paste your secret key>
Default region name [None]:      us-east-1
Default output format [None]:    json
```

**Test it:**
```bash
aws sts get-caller-identity
```

**Expected output:**
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

This confirms Terraform can authenticate as you. The Account number is your AWS
account ID — keep it handy.

> ❌ **Common error**: `Unable to locate credentials`
> **Fix**: Run `aws configure` again and make sure you paste the full access key and secret key without any extra spaces.

> ❌ **Common error**: `InvalidClientTokenId`
> **Fix**: Your access key was typed incorrectly. Delete it from IAM and create a new one.

---

## Phase 3 — Clone the Repo and Set Your Password

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
cd YOUR_REPO_NAME
```

**Copy the example vars file and set your real password:**
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

**Why?** `terraform.tfvars` is where you put real secrets. It's excluded from git
(check `.gitignore`) because it contains your database password. `terraform.tfvars.example`
is the safe template you *can* commit. Never remove `terraform/terraform.tfvars` from `.gitignore`.

**Edit the file:**
```bash
nano terraform.tfvars
# or: code terraform.tfvars
```

The file looks like:
```hcl
aws_region   = "us-east-1"
project_name = "songvault"
db_username  = "songvault_user"
db_password  = "CHANGE_ME_min8chars_useLettersAndNumbers1!"
```

**Change `db_password` to something real. Password rules:**
- At least 8 characters
- At least one uppercase letter
- At least one number
- **No special characters like `@ / " ' \ ` (these break psycopg2's connection string)**

**Good example**: `SongVault2024Pw`

Save and close the file.

---

## Phase 4 — Initialize Terraform

`terraform init` downloads the AWS provider plugin. Think of it like `npm install` —
it downloads the code Terraform needs to talk to AWS. This only needs to be run once
per project (or when you change provider versions).

```bash
terraform init
```

**Expected output:**
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.x.x...
- Installed hashicorp/aws v5.x.x (signed by HashiCorp)

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure.
```

> ❌ **Common error**: `Failed to install provider`
> **Fix**: Check your internet connection. If you're behind a corporate proxy, configure `HTTPS_PROXY`.

> ❌ **Common error**: `Required plugins are not installed`
> **Fix**: Delete the `.terraform` directory and run `terraform init` again.

---

## Phase 5 — Preview What Will Be Built

`terraform plan` shows you exactly what Terraform is going to create **before**
it creates anything. Always read the plan before applying — this is how you catch
mistakes before they cost money.

```bash
terraform plan
```

**Expected output (abbreviated):**
```
Terraform will perform the following actions:

  # aws_vpc.main will be created
  + resource "aws_vpc" "main" {
      + cidr_block           = "10.0.0.0/16"
      + enable_dns_hostnames = true
      ...
  }

  # aws_subnet.public_1 will be created
  ...

  # aws_db_instance.postgres will be created
  + resource "aws_db_instance" "postgres" {
      + engine         = "postgres"
      + instance_class = "db.t3.micro"
      ...
  }

  ...

Plan: 30 to add, 0 to change, 0 to destroy.
```

Read through the list. You should see resources for: VPC, subnets, internet gateway,
NAT gateway, security groups, RDS, IAM role, launch template, ASG, ALB.

> ❌ **Common error**: `Error: configuring Terraform AWS Provider: no valid credential sources found`
> **Fix**: Your AWS credentials aren't configured. Go back to Phase 2.

> ❌ **Common error**: `Error: Invalid provider configuration`
> **Fix**: Make sure you're in the `terraform/` directory when running commands.

---

## Phase 6 — Deploy

`terraform apply` builds everything. It shows you the plan again and asks for
confirmation before making any changes.

```bash
terraform apply
```

You'll see the plan, then:
```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value:
```

Type `yes` and press Enter.

**What to expect while it runs:**
```
aws_vpc.main: Creating...
aws_vpc.main: Creation complete after 2s [id=vpc-0abc123...]
aws_internet_gateway.main: Creating...
aws_internet_gateway.main: Creation complete after 1s
...
aws_db_instance.postgres: Creating...
aws_db_instance.postgres: Still creating... [1m0s elapsed]
aws_db_instance.postgres: Still creating... [2m0s elapsed]
...
aws_db_instance.postgres: Creation complete after 5m30s
...
Apply complete! Resources: 30 added, 0 changed, 0 destroyed.

Outputs:

alb_url      = "http://songvault-alb-1234567890.us-east-1.elb.amazonaws.com"
asg_name     = "songvault-asg"
rds_endpoint = "songvault-db.xxxx.us-east-1.rds.amazonaws.com"
vpc_id       = "vpc-0abc123..."
```

**This takes 5–10 minutes.** The longest parts are RDS startup (~5 min) and EC2
instances running their bootstrap script (~3 min) after that.

Copy the `alb_url`. That's your app. **But wait 3–5 more minutes** before opening
it — the EC2 instances are still bootstrapping.

> ❌ **Common error**: `Error creating DB Instance: InvalidParameterValue: The parameter MasterUserPassword is not valid`
> **Fix**: Your password has invalid characters. Edit `terraform.tfvars` and use only letters and numbers.

> ❌ **Common error**: `Error: creating EC2 Instance Profile: EntityAlreadyExists`
> **Fix**: A previous partial deployment left IAM resources behind. Run `terraform destroy` first, then `terraform apply`.

> ❌ **Common error**: `Error: error creating EIP: AddressLimitExceeded`
> **Fix**: You've hit the default Elastic IP limit (5 per region). Release unused EIPs in the AWS Console → EC2 → Elastic IPs.

---

## Phase 7 — Open the App

Wait 3–5 minutes after `terraform apply` finishes, then open the `alb_url` in
your browser. You should see the SongVault homepage.

**To see the URL again any time:**
```bash
terraform output alb_url
```

**If you see a `502 Bad Gateway`:**
The EC2 instances are still bootstrapping. Wait 2 more minutes and refresh.
This is normal — the ALB tries to route traffic before the app is ready.

**If you see `ERR_CONNECTION_TIMED_OUT` after 10 minutes:**
The bootstrap may have failed. Check the logs (see below).

**How to check if the app started correctly on EC2 (using SSM — no SSH needed):**
1. Open AWS Console → Systems Manager → Session Manager
2. Click "Start Session"
3. Select one of your `songvault-app-server` instances → Start Session
4. In the terminal that opens:

```bash
# Check if the service is running
sudo systemctl status songvault

# Check the bootstrap log
sudo tail -50 /var/log/songvault-bootstrap.log

# Check the app logs
sudo journalctl -u songvault -n 50
```

**Expected `systemctl status` output:**
```
● songvault.service - SongVault Flask App
     Loaded: loaded (/etc/systemd/system/songvault.service; enabled; vendor preset: enabled)
     Active: active (running) since ...
   Main PID: 1234 (gunicorn)
```

---

## Phase 8 — Test the App

1. **Add your first song**: click "➕ Add Song"
   - Title: `Bohemian Rhapsody`
   - Key: `B-flat minor`
   - Tempo: `72`
   - Mood: `epic`
   - Duration: `5.55` (5 min 33 sec = 333 seconds)
   - Lyrics: paste some lyrics
   - Click "Save Song"

2. **Add a second song**: repeat with a different song.

3. **Build your setlist**: click "🎶 Setlist"
   - Check both songs
   - Click "Update Setlist"
   - You should see the ordered list and total runtime at the bottom.

4. **Verify total runtime**: add up the individual durations and confirm the total matches.

---

## Phase 9 — Prove High Availability (The Most Important Test)

High availability means the app keeps running even when individual servers fail.
This is the core of what you built. Companies pay cloud engineers specifically to
build and prove this.

### Step 1: Confirm 2 instances are running
Open AWS Console → EC2 → Instances. You should see two instances named
`songvault-app-server` with status "Running".

### Step 2: Keep the app open in your browser
Navigate to your `alb_url` and keep the tab open.

### Step 3: Terminate one instance
- Select one instance → Actions → Instance State → Terminate Instance
- Confirm termination.

### Step 4: Refresh the app
Go back to your browser tab and refresh the page. **The app still works.**
The ALB was already routing traffic to the other instance.

### Step 5: Watch the ASG replace the terminated instance
Go to EC2 → Auto Scaling Groups → `songvault-asg` → Activity tab.

**Expected output:**
```
Launching a new EC2 instance: i-0abc123...
Reason: An instance was terminated.
```

Within 3–5 minutes, you'll see a new instance with status "Running".

### Step 6: Understand what just happened

> "The ASG detected the instance count dropped below minimum=2. It automatically
> launched a replacement. This took about 3–5 minutes and required zero human action.
> The app continued serving traffic from the other AZ the entire time."

**This is what you demonstrate in a cloud engineering interview.**

---

## Phase 10 — Cleanup

Each hour this stack runs costs approximately **$0.15–$0.20** (NAT Gateway is
the biggest cost at ~$0.045/hr, and it runs 24/7 even when no traffic is flowing).

**When you're done testing, always run terraform destroy:**
```bash
cd terraform
terraform destroy
```

**Expected:**
```
Plan: 0 to add, 0 to change, 30 to destroy.

Do you really want to destroy all resources?
  Terraform will only accept 'yes' as an answer.

  Enter a value: yes

aws_lb_listener.http: Destroying...
...
aws_db_instance.postgres: Destroying...
aws_db_instance.postgres: Still destroying... [1m0s elapsed]
...
Destroy complete! Resources: 30 destroyed.
```

After destroy finishes, you will not be charged anything further for this project.

> ⚠️ If destroy fails mid-way, run `terraform destroy` again. It's idempotent — it
> will only try to delete resources that still exist.

---

## Phase 11 — What to Say in an Interview

Here are three talking points you can say out loud in a cloud engineering interview.
These are real, specific, and demonstrate hands-on knowledge.

---

**On the architecture:**

> *"I built a three-tier application on AWS — a load balancer in public subnets,
> app servers in private subnets, and a database in private subnets. Everything
> was provisioned with Terraform so it's reproducible. I used an Auto Scaling
> Group across two Availability Zones so the app can survive a data centre failure.
> I tested this — I terminated an instance manually and the app kept running."*

---

**On security:**

> *"I followed least-privilege for security groups — the load balancer only talks
> to app servers on port 8080, app servers only talk to the database on port 5432,
> and the database is not publicly accessible. EC2 instances have an IAM role that
> grants only CloudWatch Logs and SSM Session Manager access — no admin permissions.
> Database credentials are injected at deploy time via environment variables, never
> in source code."*

---

**On high availability:**

> *"I tested the failure scenario — I terminated an EC2 instance manually and
> confirmed the app kept serving traffic throughout. The Auto Scaling Group
> automatically launched a replacement within minutes without any human
> intervention. That's the value of self-healing infrastructure — your on-call
> rotation doesn't get paged at 3 AM for something the system can fix itself."*
