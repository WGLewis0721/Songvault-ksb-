# How RDS Works — SongVault

This document explains Amazon RDS, why SongVault uses it instead of a
self-managed PostgreSQL server, and how to discuss it in an interview.

---

## What Is RDS and Why Not Just Install PostgreSQL on EC2?

**Amazon RDS** (Relational Database Service) is a *managed* database service.
You tell AWS what database engine you want (PostgreSQL, MySQL, etc.) and it
handles everything operational:

| Task | Self-managed (PostgreSQL on EC2) | RDS |
|------|----------------------------------|-----|
| Install & configure PostgreSQL | You do it | AWS does it |
| OS patching | You do it | AWS does it |
| Database engine upgrades | You do it | AWS does it (or schedules it) |
| Automated backups | You set up cron jobs | Built-in, configurable retention |
| Point-in-time recovery | Complex to set up | One checkbox |
| Multi-AZ failover | Requires replication setup | One option (`multi_az = true`) |
| Storage auto-scaling | Manual | Optional, automatic |

For a portfolio project the difference in cost is minimal, but the operational
simplicity is enormous. In a real company, using RDS for databases you don't
need to customise deeply is standard practice.

---

## DB Subnet Groups and Why Private Subnets Are Used

An **RDS DB Subnet Group** tells RDS which subnets it is allowed to place
database instances into. You must provide at least two subnets in different AZs
(even if `multi_az = false`) so RDS can fail over later if needed.

```hcl
resource "aws_db_subnet_group" "main" {
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}
```

### Why Private Subnets?

Your database is the most sensitive part of the system — it contains all user
data. Placing it in a **private subnet** means:

1. **No direct internet access**: there is no route from the internet to the
   private subnet, so nobody can attempt to connect to PostgreSQL port 5432
   from outside the VPC.
2. **Security group layering**: even within the VPC, the `rds_sg` security
   group only allows TCP 5432 from `app_sg`. A compromised EC2 instance that
   doesn't have `app_sg` attached still cannot reach the database.
3. **Compliance**: most security frameworks (SOC 2, PCI-DSS, HIPAA) require
   databases to be isolated from public networks. Starting with private subnets
   is the right habit.

---

## Security Group Rules for RDS

```
rds_sg inbound rules:
  TCP 5432  ←  source: app_sg only
```

This means:
- ✅ EC2 instances with `app_sg` → can connect on 5432.
- ❌ ALB (has `alb_sg`) → **cannot** connect to RDS.
- ❌ Internet → **cannot** connect to RDS (private subnet + no matching rule).
- ❌ Any other EC2 instance that doesn't have `app_sg` → **cannot** connect.

This is the **principle of least privilege** applied to network access. The
database only accepts connections from the application that needs it.

---

## `skip_final_snapshot` — When to Change It in Production

```hcl
skip_final_snapshot = true
```

When you run `terraform destroy`, RDS offers to take a final backup snapshot
before it deletes the database. Setting `skip_final_snapshot = true` means
**no snapshot is taken** — the data is gone permanently.

This is fine for:
- Development and portfolio environments where you can recreate data.
- Running `terraform destroy` as part of cleanup after a demo.

**Change this in production:**

```hcl
skip_final_snapshot       = false
final_snapshot_identifier = "songvault-final-backup"
```

This causes `terraform destroy` to pause, create a named snapshot, and only
then delete the instance. You can restore from that snapshot later.

For critical production databases you should also enable:
- `backup_retention_period = 7` (7 days of automated daily backups)
- `deletion_protection = true` (prevents accidental deletion entirely)

---

## What the Connection String Looks Like

RDS exposes a **DNS endpoint** such as:

```
songvault-db.c9akciq32.us-east-1.rds.amazonaws.com
```

The full PostgreSQL connection string your application uses:

```
postgresql://songvault_user:YOUR_PASSWORD@songvault-db.c9akciq32.us-east-1.rds.amazonaws.com:5432/songvault
```

### How app.py Uses It

app.py does **not** use a connection URL string. Instead it uses individual
parameters from environment variables:

```python
conn = psycopg2.connect(
    host=os.environ.get("DB_HOST"),     # RDS endpoint DNS name
    dbname=os.environ.get("DB_NAME"),   # "songvault"
    user=os.environ.get("DB_USER"),     # "songvault_user"
    password=os.environ.get("DB_PASS"), # the secret password
)
```

These environment variables are injected into the EC2 instance at boot time via
the `/etc/songvault.env` file created by `user-data.sh`. The systemd service
reads that file with `EnvironmentFile=/etc/songvault.env`.

The file is:
1. Created from Terraform's `templatefile()` with the real RDS endpoint and
   credentials.
2. Owned by root with permissions `600` so no other OS user can read it.
3. Never committed to source control — it only exists on the running instance.

---

## What a Cloud Engineer Would Say in an Interview

> *"SongVault uses Amazon RDS for PostgreSQL rather than a self-managed
> database because RDS handles automated backups, patching, and can provide
> automatic failover with a single configuration change (`multi_az = true`).
> The RDS instance lives in private subnets with a security group that only
> accepts TCP 5432 from the application's security group — it is completely
> unreachable from the internet. Database credentials are passed to the
> application via environment variables injected through a systemd
> EnvironmentFile, keeping secrets out of source control. For this portfolio
> project I set `skip_final_snapshot = true` for convenience, but in
> production I'd set it to false, enable `deletion_protection`, and configure
> a 7-day backup retention period."*

Key talking points:
- **Managed service** — AWS handles ops, you focus on the application.
- **Private subnets + security group chaining** — defence in depth.
- **Credentials via environment variables** — secrets never in source code.
- **skip_final_snapshot** — know when to change it for production.
- **Multi-AZ option** — understand what it does even if not enabled here.
