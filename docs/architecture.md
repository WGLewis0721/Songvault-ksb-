# SongVault Architecture

## Overview

SongVault is a Flask web application deployed on AWS using a classic three-tier
architecture: a public-facing load balancer, a private compute layer, and a
managed database. Every component has a specific job and together they make the
application **highly available** — it keeps running even when individual
pieces fail.

---

## Architecture Diagram

```
                         ┌──────────────────────────────────────────────┐
                         │                  AWS VPC                     │
                         │  (10.0.0.0/16 — your private network slice) │
                         │                                              │
  Users on the           │  ┌──────────────────────────────────────┐   │
  Internet               │  │       PUBLIC SUBNETS (AZ-1 & AZ-2)   │   │
      │                  │  │                                      │   │
      │  HTTP :80        │  │   ┌──────────────────────────────┐  │   │
      └──────────────────┼──┼──►│  Application Load Balancer   │  │   │
                         │  │   │        (ALB)                 │  │   │
                         │  │   └──────────────┬───────────────┘  │   │
                         │  └──────────────────┼───────────────────┘   │
                         │                     │ HTTP :8080             │
                         │  ┌──────────────────┼───────────────────┐   │
                         │  │      PRIVATE SUBNETS (AZ-1 & AZ-2)   │   │
                         │  │                  │                   │   │
                         │  │   ┌──────────────┴─────────────┐    │   │
                         │  │   │   Auto Scaling Group (ASG)  │    │   │
                         │  │   │  ┌─────────┐  ┌─────────┐  │    │   │
                         │  │   │  │  EC2    │  │  EC2    │  │    │   │
                         │  │   │  │ AZ-1    │  │ AZ-2    │  │    │   │
                         │  │   │  │Flask app│  │Flask app│  │    │   │
                         │  │   │  └────┬────┘  └────┬────┘  │    │   │
                         │  │   └───────┼─────────────┼───────┘    │   │
                         │  │           │  TCP :5432  │            │   │
                         │  │   ┌───────┴─────────────┴───────┐    │   │
                         │  │   │   RDS PostgreSQL (primary)   │    │   │
                         │  │   │        (private subnet)      │    │   │
                         │  │   └──────────────────────────────┘    │   │
                         │  └────────────────────────────────────────┘   │
                         └──────────────────────────────────────────────┘
```

---

## Why Each Component Exists

### Internet → ALB

The **Application Load Balancer (ALB)** is the only component with a public IP
address. Users connect to it on port 80. The ALB then forwards each request to
one of the healthy EC2 instances. This separation means:

- EC2 instances never need to be exposed to the internet directly.
- The ALB can distribute traffic evenly across multiple instances.
- If you add HTTPS later, you only need to configure it in one place.

### ALB → EC2 (Auto Scaling Group)

The **Auto Scaling Group (ASG)** manages a fleet of EC2 instances running the
Flask application. It keeps a minimum of 2 instances (one per Availability
Zone) running at all times. Key benefits:

- **Redundancy**: if one instance dies, traffic flows to the other.
- **Self-healing**: the ASG replaces unhealthy instances automatically.
- **Scalability**: you can increase `max_size` and add a scaling policy to
  handle traffic spikes.

### EC2 → RDS PostgreSQL

**Amazon RDS** manages the PostgreSQL database. The app connects to it using
environment variables (DB_HOST, DB_NAME, DB_USER, DB_PASS) so credentials
never live in source code.

---

## What Happens If One EC2 Instance Dies?

1. The ALB's health check (HTTP GET on port 8080 every 30 seconds) detects that
   the instance is no longer responding.
2. After 3 consecutive failures the ALB marks it as **unhealthy** and stops
   sending traffic to it.
3. The ASG also notices the unhealthy instance and **terminates** it.
4. The ASG launches a **replacement** EC2 instance using the Launch Template.
5. Once the new instance passes health checks, the ALB starts sending it traffic.

From the user's perspective, there may be a brief pause on in-flight requests
to the dead instance, but the service as a whole keeps running.

---

## What Does "Private Subnet" Mean?

A **public subnet** has a route to the **Internet Gateway** — resources in it
can send and receive traffic from the internet.

A **private subnet** has no route to the Internet Gateway. Resources in it
**cannot be reached from the internet**. They can still reach the internet
*outbound* via the **NAT Gateway** (to download packages, etc.), but nobody
outside can initiate a connection to them.

### Why Is RDS in a Private Subnet?

Your database contains all your song data. Putting it in a private subnet
means:

- No one on the internet can even attempt to connect to it.
- Only EC2 instances in `app_sg` (your Flask app servers) can reach it on
  port 5432.
- Even if an attacker somehow got into the VPC, the RDS security group blocks
  them unless they're in `app_sg`.

This is called **defence in depth** — multiple layers of protection.

---

## Key Terms Glossary

| Term | Plain-English Meaning |
|------|-----------------------|
| **VPC** | Virtual Private Cloud — your isolated private network inside AWS |
| **Subnet** | A smaller network range carved out of the VPC CIDR |
| **AZ (Availability Zone)** | A physically separate data centre within an AWS Region |
| **ALB** | Application Load Balancer — distributes HTTP traffic across EC2 instances |
| **ASG** | Auto Scaling Group — keeps N instances running and replaces unhealthy ones |
| **RDS** | Relational Database Service — managed PostgreSQL (AWS handles patching/backups) |
| **Security Group** | A stateful firewall that controls what traffic can reach a resource |
| **Launch Template** | The blueprint (AMI + instance type + user data) used by the ASG to create instances |
| **NAT Gateway** | Lets private instances reach the internet outbound without exposing them inbound |
| **IGW (Internet Gateway)** | The door between your VPC and the public internet |
