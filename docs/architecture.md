# SongVault Architecture

## Overview

SongVault is a Flask web application for managing song lyrics and setlists,
deployed on AWS using a classic three-tier architecture: a public-facing load
balancer, a private compute layer, and a managed database. Every component has
a specific job, and together they make the application **highly available** —
it keeps running even when individual pieces fail.

---

## Architecture Diagram

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
                        │       │              │            │
                        │       └──────┬───────┘            │
                        │              │                    │
                        │       ┌──────▼──────┐             │
                        │       │  RDS Postgres│             │
                        │       │  (private)   │             │
                        │       └─────────────┘             │
                        └─────────────────────────────────┘
```

---

## What Each Component Does

| Component | Plain-English Purpose |
|-----------|-----------------------|
| **VPC** | Your isolated private network inside AWS — nothing gets in unless you open a door |
| **Public Subnet (×2)** | Network zones that face the internet — only the ALB and NAT Gateway live here |
| **Private Subnet (×2)** | Network zones with no internet access — EC2 app servers and RDS live here |
| **ALB** | Receives all user traffic on port 80 and distributes it to healthy EC2 instances |
| **NAT Gateway** | Lets private EC2 instances download packages without exposing them to inbound internet traffic |
| **EC2 (ASG)** | Runs the Flask application; the ASG keeps two instances alive across two AZs |
| **RDS PostgreSQL** | Managed database — AWS handles backups, patching, and restarts |
| **Security Groups** | Firewall rules that chain traffic: internet → ALB → EC2 → RDS |

---

## The Request Lifecycle

What happens step-by-step when a user loads the SongVault homepage:

1. User opens `http://alb-url` in a browser.
2. DNS resolves the ALB's domain name to one of its public IP addresses.
3. The ALB receives the HTTP request on port 80.
4. The ALB selects a healthy EC2 instance from its target group.
5. The ALB forwards the request to that EC2 instance on port 8080.
6. The Flask app on the EC2 instance queries RDS PostgreSQL via port 5432.
7. RDS returns the song rows.
8. Flask renders `index.html` with the data and returns the HTML response.
9. The ALB passes the response back to the user's browser.

---

## What Happens When One EC2 Instance Dies?

1. The ALB's health check (`GET /` on port 8080 every 30 seconds) detects the
   instance is no longer responding.
2. After 3 consecutive failures the ALB marks it **unhealthy** and stops sending
   traffic to it.
3. The Auto Scaling Group also sees the unhealthy status and **terminates** the bad
   instance.
4. The ASG launches a **replacement** EC2 instance from the Launch Template.
5. The new instance runs the user-data bootstrap script, starts the Flask app, and
   begins passing health checks.
6. The ALB starts sending traffic to the new instance.

From the user's perspective, existing traffic flows to the healthy instance in the
other AZ during the 3–5 minute recovery window. The service never goes fully down.

---

## Why Private Subnets Exist

A **private subnet** has no route to the Internet Gateway. Anything in a private
subnet cannot be reached by an attacker on the internet — they would have to first
compromise the ALB or somehow get inside the VPC.

In SongVault:
- **EC2 app servers** are in private subnets. The only traffic they receive is from
  the ALB, enforced by the `app_sg` security group.
- **RDS** is in a private subnet. The only traffic it receives is from EC2 app
  servers, enforced by the `rds_sg` security group.

This means even if someone discovered the IP address of an EC2 instance or the RDS
endpoint, they cannot connect — the private subnet and security groups block them.

---

## Key Terms Glossary

| Term | Plain-English Meaning |
|------|-----------------------|
| **VPC** | Virtual Private Cloud — your isolated private network inside AWS |
| **Subnet** | A smaller IP range inside the VPC, pinned to one Availability Zone |
| **AZ** | Availability Zone — a physically separate data centre within an AWS Region |
| **ALB** | Application Load Balancer — distributes HTTP traffic across EC2 instances |
| **ASG** | Auto Scaling Group — keeps N instances running and replaces unhealthy ones |
| **Launch Template** | The blueprint (AMI + instance type + user data) used by the ASG |
| **RDS** | Relational Database Service — managed PostgreSQL |
| **Security Group** | A stateful firewall that controls what traffic can reach a resource |
| **NAT Gateway** | Lets private instances reach the internet outbound without exposing them inbound |
| **IGW** | Internet Gateway — the door between your VPC and the public internet |
