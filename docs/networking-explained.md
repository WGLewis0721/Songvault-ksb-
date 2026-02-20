# Networking Explained — SongVault

This document explains every networking concept used in SongVault in plain
English, with analogies. If you're new to cloud networking, start here.

---

## What Is a VPC and Why Create Your Own?

**VPC** stands for *Virtual Private Cloud*. Think of it as **renting an empty
floor in an office building**. AWS owns the building (the physical data
centres), but your floor is completely private — only you decide who gets a
keycard and where the internal walls go.

When you open an AWS account you get a *default VPC* that's already configured.
For a real application you create your **own VPC** because:

- You control the IP address ranges.
- You decide which resources are public vs private.
- You can peer it with other VPCs or connect it to your on-premises network.
- It's a clean slate — no accidentally shared rules from the default VPC.

In SongVault the VPC CIDR is `10.0.0.0/16`, giving you 65,536 private IP
addresses to assign to subnets.

---

## Public vs Private Subnets

A **subnet** is a slice of your VPC's IP address space, locked to one
Availability Zone.

**Analogy**: imagine your VPC is an office building.
- A **public subnet** is the **lobby** — anyone can walk in from the street.
- A **private subnet** is the **back office** — only authorised staff can enter,
  and visitors never go there directly.

| Feature | Public Subnet | Private Subnet |
|---------|---------------|----------------|
| Route to Internet Gateway | ✅ Yes | ❌ No |
| Resources get public IPs | ✅ (optional) | ❌ |
| Reachable from internet | ✅ | ❌ |
| Can reach internet (outbound) | ✅ Via IGW | ✅ Via NAT Gateway |
| Used for | ALB | EC2 app servers, RDS |

In SongVault:
- `10.0.1.0/24` and `10.0.2.0/24` are **public** — the ALB lives here.
- `10.0.3.0/24` and `10.0.4.0/24` are **private** — EC2 and RDS live here.

---

## Internet Gateway vs NAT Gateway

### Internet Gateway (IGW)

Think of the IGW as the **front door of the building**. It enables
*bidirectional* internet traffic — resources in public subnets can:
- Receive connections from the internet (inbound).
- Send connections to the internet (outbound).

The ALB uses the IGW to accept HTTP requests from users.

### NAT Gateway

The NAT (Network Address Translation) Gateway is like a **one-way mail
forwarding service**. It lets resources in *private* subnets:
- Send outbound connections to the internet (to download packages, reach AWS
  APIs, etc.).
- **But**: nothing on the internet can initiate a connection *back* to them.

In SongVault, EC2 instances in private subnets use the NAT Gateway to run
`apt-get` and `pip install` during the user-data bootstrap — without ever
being exposed to inbound internet traffic.

| | Internet Gateway | NAT Gateway |
|-|-----------------|-------------|
| Direction | Inbound + Outbound | Outbound only |
| Who uses it | Public subnets | Private subnets |
| Who can initiate | Anyone | Only private resources |
| Cost | Free | ~$0.045/hr + data |

---

## Route Tables — What They Are and How They Work

A **route table** is like a **GPS system** for network packets. Every subnet is
associated with exactly one route table. When a packet needs to go somewhere,
the route table tells it which door to use.

SongVault has two route tables:

### Public Route Table
```
Destination    Target
10.0.0.0/16    local          ← traffic within the VPC stays local
0.0.0.0/0      igw-xxxxxxxx   ← everything else goes to the Internet Gateway
```
Associated with: `public-1`, `public-2`

### Private Route Table
```
Destination    Target
10.0.0.0/16    local          ← VPC-internal traffic stays local
0.0.0.0/0      nat-xxxxxxxx   ← outbound internet goes via NAT Gateway
```
Associated with: `private-1`, `private-2`

---

## Why Are App Servers in Private Subnets but the ALB Is Public?

The ALB *must* be in public subnets because its job is to receive traffic from
users on the internet. It needs a public IP address and a route to the IGW.

The EC2 app servers **do not** need to be reachable from the internet. They
only need to receive traffic from the ALB. Putting them in private subnets
provides an extra layer of security:

- Even if someone guessed an EC2 instance's IP address, they couldn't connect
  to it — there's no route from the internet to private subnets.
- The only way to reach the app servers is through the ALB, which enforces the
  security group rules.

This is the standard **"DMZ" pattern** used in virtually every production web
application.

---

## CIDR Notation Explained Simply

**CIDR** (Classless Inter-Domain Routing) notation looks like `10.0.0.0/16`.
It tells you two things:

1. **The network address**: `10.0.0.0` — where the network starts.
2. **The prefix length** (the `/16`): how many bits are "fixed" (the network
   part) and how many are free (the host part).

### Quick Reference

| CIDR | Fixed bits | Free bits | Number of IP addresses |
|------|-----------|-----------|------------------------|
| `10.0.0.0/16` | 16 | 16 | 65,536 |
| `10.0.1.0/24` | 24 | 8 | 256 |
| `10.0.2.0/24` | 24 | 8 | 256 |

### SongVault's IP Plan

```
VPC:       10.0.0.0/16  → parent block (65,536 addresses)
  public-1:  10.0.1.0/24  → 256 addresses (ALB node 1)
  public-2:  10.0.2.0/24  → 256 addresses (ALB node 2)
  private-1: 10.0.3.0/24  → 256 addresses (EC2 + RDS in AZ-1)
  private-2: 10.0.4.0/24  → 256 addresses (EC2 + RDS in AZ-2)
```

The subnets must all fit *inside* the VPC CIDR — `/24` blocks starting with
`10.0.x` are well within the `/16` range.

---

## Summary

| Concept | One-Liner |
|---------|-----------|
| VPC | Your private network slice inside AWS |
| Subnet | A smaller IP range inside the VPC, pinned to one AZ |
| Public subnet | Has an IGW route — resources can be internet-facing |
| Private subnet | No IGW route — resources are shielded from the internet |
| IGW | The door between your VPC and the internet (bidirectional) |
| NAT Gateway | One-way exit for private resources to reach the internet |
| Route table | The routing rules that decide where packets go |
| CIDR | The notation for specifying IP address ranges |
