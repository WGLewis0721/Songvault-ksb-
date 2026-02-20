# Networking Explained — SongVault

This document explains every networking concept used in SongVault in plain
English, with real-world analogies. If you're new to cloud networking, start here.

---

## What Is a VPC and Why Create Your Own?

**VPC** stands for *Virtual Private Cloud*.

**Analogy**: think of AWS as a giant office building with thousands of tenants.
When you sign up, you get your own private floor — completely isolated from everyone
else. You decide where the internal walls go, which doors face the street, and who
gets a keycard.

When you open an AWS account you get a *default VPC* that's already configured.
For a real application you create your **own VPC** because:

- You control the IP address ranges.
- You decide which resources are public vs private.
- It's a clean slate with no accidentally shared settings from the default VPC.

In SongVault the VPC CIDR is `10.0.0.0/16`, giving you 65,536 private IP
addresses to assign to subnets.

---

## Public vs Private Subnets

A **subnet** is a slice of your VPC's IP address space, locked to one
Availability Zone. Think of subnets as rooms on your floor.

**Analogy**: 
- A **public subnet** is like the **lobby** — it faces the street, has a front door,
  and anyone can walk in from outside.
- A **private subnet** is like the **back office** — no external door, no street
  access. Visitors never go there directly. Only staff can get in.

| Feature | Public Subnet | Private Subnet |
|---------|---------------|----------------|
| Route to Internet Gateway | ✅ Yes | ❌ No |
| Resources get public IPs | Optional | ❌ Never |
| Reachable from internet | ✅ Yes | ❌ No |
| Can reach internet (outbound) | ✅ Via IGW | ✅ Via NAT Gateway |
| Used for | ALB | EC2 app servers, RDS |

In SongVault:
- `10.0.1.0/24` and `10.0.2.0/24` are **public** — the ALB lives here.
- `10.0.101.0/24` and `10.0.102.0/24` are **private** — EC2 and RDS live here.

---

## CIDR Notation Explained Simply

**CIDR** (Classless Inter-Domain Routing) notation looks like `10.0.0.0/16`.

The `/16` tells you how many IP addresses are in that range. The bigger the
number after the slash, the *fewer* addresses.

**Your building analogy**: 
- `10.0.0.0/16` = Your whole building has 65,536 room numbers available.
- `10.0.1.0/24` = One corridor in the building with 256 rooms.

```
VPC:        10.0.0.0/16  → 65,536 addresses (the whole building)
  public-1:   10.0.1.0/24   → 256 addresses (corridor 1, faces street)
  public-2:   10.0.2.0/24   → 256 addresses (corridor 2, faces street)
  private-1:  10.0.101.0/24 → 256 addresses (corridor 101, no street access)
  private-2:  10.0.102.0/24 → 256 addresses (corridor 102, no street access)
```

All subnet CIDRs fit *inside* the VPC CIDR — `10.0.x` is always within `10.0.0.0/16`.

---

## Internet Gateway (IGW)

The **Internet Gateway** is the **front door of the building**. It connects the
public subnets to the internet bidirectionally:

- Resources in public subnets can **receive** connections from the internet.
- Resources in public subnets can **send** connections to the internet.

The ALB uses the IGW to accept HTTP requests from users around the world.
Without the IGW, nobody could reach your app.

---

## NAT Gateway

The **NAT Gateway** is like a **mail proxy for back-office staff**. 

Staff in the back office (private EC2 instances) need to send packages out to
the internet (to download Python libraries). But you don't want anyone from the
street walking into the back office uninvited.

The NAT Gateway solves this:
- Private EC2 instances send their outbound requests *through* the NAT Gateway.
- The NAT Gateway has a public IP (the Elastic IP) and forwards the request on
  their behalf.
- The response comes back to the NAT Gateway, which forwards it to the EC2 instance.
- Nothing from the internet can initiate a connection *back* to the private instances.

**Why does NAT Gateway cost money?** It processes every byte of outbound traffic
from your private subnets. The EC2 instances use it to `apt-get install` and
`pip3 install` during bootstrap — after that, outbound traffic is minimal.

---

## Route Tables

A **route table** is like a **building directory**. When a packet needs to go
somewhere, the route table tells it which door to use.

Every subnet has exactly one route table. SongVault has two:

### Public Route Table
```
Destination    Target
10.0.0.0/16    local          ← traffic within the VPC stays inside
0.0.0.0/0      igw-xxxxx      ← everything else goes to the Internet Gateway
```
*Applied to: public-1, public-2*

### Private Route Table
```
Destination    Target
10.0.0.0/16    local          ← VPC-internal traffic stays inside
0.0.0.0/0      nat-xxxxx      ← outbound internet goes via NAT Gateway
```
*Applied to: private-1, private-2*

---

## Why App Servers Are in Private Subnets

The EC2 app servers **do not need** to be reachable from the internet. They
only need to receive traffic from the ALB. Putting them in private subnets
provides an extra layer of security:

- Even if someone guessed an EC2 instance's IP address, the private subnet has
  no Internet Gateway route — the connection can't be established.
- The only way to reach the app servers is through the ALB, which enforces its
  own security group rules.

This is the standard **DMZ pattern** used in virtually every production web application.

---

## Traffic Flow Diagrams

### User Loads the Page
```
User Browser
    │
    ▼  (HTTP port 80)
Internet Gateway
    │
    ▼
ALB (public subnet, alb_sg allows port 80)
    │
    ▼  (HTTP port 8080)
EC2 App Server (private subnet, app_sg allows port 8080 from ALB only)
    │
    ▼  (TCP port 5432)
RDS PostgreSQL (private subnet, rds_sg allows port 5432 from EC2 only)
```

### EC2 Instance Installing Packages During Bootstrap
```
EC2 App Server (private subnet, no public IP)
    │
    ▼  (outbound request)
NAT Gateway (public subnet, has Elastic IP)
    │
    ▼  (outbound via Elastic IP)
Internet Gateway
    │
    ▼
pypi.org / apt repositories
    │
    ▼  (response flows back the same path)
EC2 App Server receives the package
```
