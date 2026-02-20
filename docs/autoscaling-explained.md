# Auto Scaling Explained — SongVault

This document explains how the SongVault Auto Scaling Group (ASG) works, why
it matters for high availability, and how to talk about it in a cloud
engineering interview.

---

## What Does an Auto Scaling Group Do?

An **Auto Scaling Group (ASG)** is AWS's way of saying: *"Keep this many
servers running and healthy for me, always."*

You tell it three numbers — minimum, desired, and maximum — and it does the
rest:

- **Launches** instances when there aren't enough.
- **Terminates** instances that fail health checks and launches replacements.
- **Scales out** (adds instances) when load increases (if you add scaling
  policies).
- **Scales in** (removes instances) when load drops.

Without an ASG, if an EC2 instance dies your app goes down until you manually
notice and restart it. With an ASG, the replacement happens in minutes,
automatically, even at 3 AM.

---

## Min / Desired / Max Capacity

```
min_size         = 2   ← never fewer than 2 instances
desired_capacity = 2   ← start with 2 instances
max_size         = 4   ← never more than 4 instances
```

| Setting | When It Matters |
|---------|----------------|
| `min_size` | Guarantees at least this many instances are always running. Set to the minimum needed for availability (≥ 1 per AZ). |
| `desired_capacity` | The number of instances the ASG aims for right now. You or a scaling policy can change it. |
| `max_size` | A safety cap — prevents runaway scaling that could cost you thousands of dollars. |

**Example**: if a scaling policy detects high CPU, it sets `desired_capacity =
4`. The ASG launches 2 more instances. When CPU drops, it scales back down to
2. `max_size` ensures it never spins up 100 instances by accident.

For SongVault, `desired_capacity = 2` with one instance per AZ gives us
redundancy without wasting money.

---

## Launch Templates — What They Are and Why They're Better Than AMIs Alone

A **Launch Template** is the *blueprint* the ASG uses when it needs to create a
new instance. It captures everything about an instance:

- **AMI**: the base operating system image (Ubuntu 22.04 in our case).
- **Instance type**: `t3.micro`.
- **Security groups**: which firewall rules to apply.
- **User data**: the bash script that bootstraps the app on first boot.

### Why Not Just Use an AMI?

You *could* bake a custom AMI with everything pre-installed. But:

- Every time your app changes, you'd need to build a new AMI.
- Launch Templates separate "what machine to start" from "how to configure
  it" — the user-data script handles configuration at boot time.
- Launch Templates support versioning — you can roll out changes to a new
  version and the ASG picks it up with `version = "$Latest"`.

In SongVault, the user-data script clones the repo from GitHub and starts the
Flask app. This means you can update the app by pushing to GitHub and replacing
instances — no new AMI needed.

---

## ELB Health Checks — How the ASG Uses Them

The ASG can use two types of health checks:

| Type | What It Checks |
|------|---------------|
| **EC2** (default) | Is the instance itself powered on? (very basic) |
| **ELB** | Does the ALB's HTTP health check pass? (application-level) |

SongVault uses `health_check_type = "ELB"`. Here's what that means:

1. The ALB sends an HTTP GET to `http://<instance-ip>:8080/` every 30 seconds.
2. If the instance returns a 200 OK twice in a row → **healthy**.
3. If it fails 3 times in a row → **unhealthy**.
4. The ASG is notified of the unhealthy status.
5. The ASG **terminates** the bad instance.
6. The ASG **launches a new one** using the Launch Template.
7. The new instance runs user-data, starts the Flask app, and begins passing
   health checks.
8. The ALB routes traffic to the new instance.

The `health_check_grace_period = 300` gives new instances 5 minutes to finish
booting before health checks start — preventing them from being terminated
immediately for "failing" while still setting up.

---

## Why 2 AZs Matter for Real High Availability

An **Availability Zone (AZ)** is a physically separate data centre with its
own power, cooling, and network connections. AWS guarantees that two AZs in the
same region will not fail at the same time.

SongVault spreads instances across **AZ-1 (private-1)** and **AZ-2
(private-2)**:

```
AZ-1:  1 EC2 instance  +  RDS primary
AZ-2:  1 EC2 instance  +  (RDS standby if multi_az = true)
```

If AZ-1 loses power or has a network issue:
- The EC2 instance in AZ-1 becomes unreachable.
- The ALB stops sending traffic to it.
- The ASG launches a replacement in AZ-2 (or another AZ).
- Users experience a brief blip but the service recovers automatically.

**Single-AZ deployments** are cheaper but a single AZ failure takes down the
entire app. For a portfolio project, 2 AZs is the right choice to demonstrate
real HA architecture.

---

## What a Cloud Engineer Would Say in an Interview

> *"In SongVault I configured an Auto Scaling Group with a minimum of 2
> instances spread across two Availability Zones. This guarantees the
> application remains available even if an entire AZ goes down. I used ELB
> health checks rather than EC2 health checks so that the ASG replaces
> instances that are running but serving errors — not just instances that are
> powered off. The Launch Template injects database credentials via a
> templatefile-rendered user-data script, keeping secrets out of source
> control. A health_check_grace_period of 300 seconds prevents the ASG from
> prematurely terminating new instances that are still bootstrapping."*

Key talking points:
- **Min 2 instances** — never less than one per AZ.
- **ELB health checks** — application-level, not just EC2 status.
- **Launch Template with user-data** — no baked AMIs, easy updates.
- **Grace period** — prevents false-positive terminations during boot.
- **2 AZs** — protects against single-AZ failures.
