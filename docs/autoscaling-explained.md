# Auto Scaling Explained — SongVault

---

## The Problem It Solves

Without an Auto Scaling Group, if your server crashes at 2 AM, the app is down
until someone notices, wakes up, logs in, and manually restarts it. That could
be hours of downtime.

With an ASG: the ASG notices the problem within minutes, terminates the broken
instance, and launches a fresh replacement — automatically, with no human
involvement required. That's the value of self-healing infrastructure.

---

## What an ASG Does in Plain English

An **Auto Scaling Group** is a manager that watches your servers and replaces
bad ones. You give it three numbers and a blueprint, and it handles the rest:

```
min_size         = 2   ← the floor  — never fewer than 2 instances
desired_capacity = 2   ← the normal — start with and aim for 2
max_size         = 4   ← the ceiling — never more than 4 instances
```

**Analogy**: imagine a restaurant with a rule: "always have at least 2 waiters,
normally 2, never more than 4." If a waiter calls in sick, the manager (ASG)
immediately calls in a replacement. If it's Friday night and the restaurant gets
slammed, the manager can call in up to 2 more — but no more than 4 total (to
control costs).

---

## Min / Desired / Max — When Each Matters

| Setting | When It Matters | SongVault Value |
|---------|----------------|-----------------|
| `min_size` | Guarantees at least this many instances run 24/7. If the count drops below this, the ASG immediately launches more. Set ≥ 1 per AZ for real HA. | 2 |
| `desired_capacity` | The count the ASG aims for right now. You or a scaling policy can change it at runtime. | 2 |
| `max_size` | A safety cap. Prevents runaway scaling that could cost thousands. | 4 |

---

## Launch Templates — The Server Factory Blueprint

A **Launch Template** is the blueprint every new EC2 instance is stamped from.
It captures:

- **AMI**: which operating system to use (Ubuntu 22.04)
- **Instance type**: how powerful the server is (`t3.micro`)
- **Security groups**: which firewall rules apply
- **IAM profile**: which AWS permissions the instance gets
- **User data**: the bash script that runs on first boot to install the app

**Why use a Launch Template instead of baking a custom AMI?**

You *could* create a custom AMI with everything pre-installed. But:
- Every code change requires building a new AMI (slow, manual).
- Launch Templates separate "what machine to start" from "how to configure it."
- The user-data script installs the app fresh on every new instance — always
  using the latest code.
- When the template is updated, `version = "$Latest"` means the ASG automatically
  uses the newest version on its next scale-out.

---

## ELB Health Checks — How the ASG Replaces Bad Instances

The ASG can use two types of health checks:

| Type | What It Checks |
|------|---------------|
| **EC2** (basic) | Is the instance powered on and responding to AWS status checks? |
| **ELB** (application-level) | Does the ALB's HTTP health check return 200 OK? |

SongVault uses **ELB health checks** (`health_check_type = "ELB"`). This means:

1. Every 30 seconds, the ALB sends `GET /` to each EC2 instance on port 8080.
2. If it gets HTTP 200 back twice in a row → **healthy**.
3. If it gets no response (or an error) 3 times in a row → **unhealthy**.
4. The ASG is notified of the unhealthy instance.
5. The ASG terminates the bad instance.
6. The ASG launches a replacement from the Launch Template.
7. The new instance completes bootstrap and starts passing health checks.
8. The ALB starts routing traffic to the new instance.

The `health_check_grace_period = 300` gives new instances 5 minutes to finish
the bootstrap script before health checks start. Without this, a new instance
would fail health checks immediately while still installing Python packages.

---

## Why 2 Availability Zones Matter

An **Availability Zone (AZ)** is a physically separate data centre with its own
power, cooling, and network. AWS guarantees two AZs in the same region will not
fail simultaneously.

SongVault spreads instances across **private-1 (AZ1)** and **private-2 (AZ2)**:

```
AZ1  ─────────────────────────────────
     EC2 instance #1 (songvault-app-server)
     RDS primary

AZ2  ─────────────────────────────────
     EC2 instance #2 (songvault-app-server)
```

If AZ1 loses power:
- EC2 instance #1 becomes unreachable.
- The ALB stops sending traffic to it (health check fails).
- **All traffic goes to the EC2 instance in AZ2** — users keep getting responses.
- The ASG launches a replacement in AZ2 (since AZ1 is unavailable).

**Single-AZ deployments** are cheaper but a single AZ failure takes the app down
completely. For a portfolio project, 2 AZs demonstrates real HA architecture.

---

## The Full Failure → Recovery Sequence

```
T+0:00  EC2 instance in AZ1 crashes (kernel panic, OOM, whatever)
T+0:30  ALB health check #1 fails (no response on port 8080)
T+1:00  ALB health check #2 fails
T+1:30  ALB health check #3 fails — instance marked UNHEALTHY
T+1:30  ALB stops sending new requests to AZ1 instance
        (existing requests already going to AZ2 instance continue normally)
T+2:00  ASG detects instance count below min_size (2 → 1)
T+2:00  ASG terminates the unhealthy instance
T+2:00  ASG launches a new instance in private subnet (AZ1 or AZ2)
T+3:00  New instance: apt-get update, pip3 install, systemd start
T+7:00  New instance passes first health check
T+7:30  New instance passes second health check — marked HEALTHY
T+7:30  ALB begins routing traffic to new instance
T+7:30  Desired capacity restored: 2 healthy instances running
```

Total user impact: requests that were in-flight to the AZ1 instance at T+0:00
get an error. All subsequent requests go to the healthy AZ2 instance. App is
effectively down for 0 minutes from the user's perspective.

---

## What a Cloud Engineer Would Say in an Interview

- *"I configured an Auto Scaling Group with a minimum of 2 instances across two
  Availability Zones. This guarantees the app stays up even if an entire AZ fails."*

- *"I used ELB health checks rather than EC2 health checks so the ASG replaces
  instances that are running but serving errors — not just instances that are
  powered off."*

- *"The Launch Template injects database credentials via a templatefile-rendered
  user-data script. No manual SSH, no hardcoded secrets — instances configure
  themselves on boot."*
