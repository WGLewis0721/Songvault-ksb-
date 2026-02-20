# How RDS Works — SongVault

---

## Why Not Just Install PostgreSQL on EC2?

You *could* install PostgreSQL on an EC2 instance. But then you'd have to:

- Install and configure PostgreSQL yourself.
- Set up automated daily backups (and test that they actually work).
- Apply security patches when PostgreSQL releases updates.
- Monitor disk space and expand storage when it fills up.
- Set up replication to a second AZ if you want failover.
- Handle the failover logic when the primary fails.

**Amazon RDS handles all of that for you.** You just tell AWS what size database
you want and it handles the rest. You connect to it like a normal PostgreSQL
database and never think about the server underneath.

For a portfolio project, the cost difference is small, but the operational
simplicity is enormous. In real companies, using RDS for databases you don't
need to deeply customise is standard practice.

---

## DB Subnet Groups — Why Private Subnets

An **RDS DB Subnet Group** tells RDS which subnets it is allowed to place
database instances into. You must provide at least two subnets in different
AZs so RDS has room to fail over.

```hcl
resource "aws_db_subnet_group" "main" {
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}
```

We use **private subnets** because:

1. **No direct internet access**: there is no route from the internet to private
   subnets, so nobody can attempt to connect to PostgreSQL port 5432 externally.
2. **Security group layering**: even within the VPC, `rds_sg` only allows TCP 5432
   from `app_sg`. A resource that doesn't have `app_sg` can't reach the database.
3. **Best practice baseline**: most security frameworks require databases to be
   isolated from public networks. Starting with private subnets is the right habit.

---

## Storage Encryption

```hcl
storage_encrypted = true
```

This encrypts all data stored on the RDS instance's disk using AES-256. If
someone somehow obtained the physical hard drive, all they'd see is scrambled
data. It costs nothing extra and should always be enabled.

---

## Security Group Chain for RDS

```
rds_sg inbound rules:
  TCP 5432  ←  source: app_sg only
```

This means:
- ✅ EC2 instances with `app_sg` → can connect on port 5432
- ❌ ALB (`alb_sg`) → **cannot** connect to RDS
- ❌ Internet → **cannot** connect (private subnet + no matching security group rule)
- ❌ Any other EC2 instance without `app_sg` → **cannot** connect

This is the **principle of least privilege** applied to network access. The
database only accepts connections from the application that needs it, and nothing
else.

Diagram:
```
Internet                  ✗ blocked by private subnet
ALB (alb_sg)             ✗ blocked by rds_sg (source must be app_sg)
EC2 (app_sg)             ✓ allowed by rds_sg
EC2 (no app_sg)          ✗ blocked by rds_sg
```

---

## `skip_final_snapshot` — When to Change It

```hcl
skip_final_snapshot = true
```

When you run `terraform destroy`, RDS offers to take a final backup snapshot
before deleting the database. `skip_final_snapshot = true` means **no snapshot
is taken** — the data is permanently deleted.

**This is fine for:**
- Development environments where data can be recreated.
- Portfolio projects where you run `terraform destroy` as cleanup.

**Change this in production:**
```hcl
skip_final_snapshot       = false
final_snapshot_identifier = "songvault-final-${formatdate("YYYYMMDD", timestamp())}"
```

Also consider for production:
- `backup_retention_period = 7` — 7 days of automated daily backups
- `deletion_protection = true` — prevents `terraform destroy` from deleting the
  database at all until you explicitly disable it

---

## How the App Connects to RDS

RDS exposes a **DNS endpoint** such as:
```
songvault-db.c9akciq32.us-east-1.rds.amazonaws.com
```

This is the value printed in `terraform output rds_endpoint`.

### Under the Hood — Connection String
```
postgresql://songvault_user:PASSWORD@songvault-db.xxxx.us-east-1.rds.amazonaws.com:5432/songvault
```

### How app.py Uses It

app.py uses individual psycopg2 parameters, not a URL string:

```python
def get_conn():
    return psycopg2.connect(
        host=os.environ["DB_HOST"],     # the RDS endpoint DNS name
        dbname=os.environ.get("DB_NAME", "songvault"),
        user=os.environ.get("DB_USER", "songvault_user"),
        password=os.environ["DB_PASS"], # the secret password
    )
```

These environment variables are injected at boot time via `/etc/songvault.env`,
created by `user-data.sh` from Terraform's `templatefile()` values.

The file is:
1. Written by Terraform with the real RDS endpoint and credentials.
2. Protected with `chmod 600` — only root can read it.
3. Read by systemd via `EnvironmentFile=/etc/songvault.env`.
4. Never committed to source control — it only exists on running instances.

---

## What a Cloud Engineer Would Say in an Interview

- *"I used Amazon RDS for PostgreSQL rather than a self-managed database because
  RDS handles automated backups, patching, and can provide automatic failover with
  a single config change. In production I'd set multi_az = true."*

- *"The RDS instance lives in private subnets with a security group that only
  accepts TCP 5432 from the application's security group. It's completely
  unreachable from the internet — defence in depth."*

- *"Database credentials are passed via environment variables injected through a
  systemd EnvironmentFile. The file has 600 permissions and is never in source
  control. For production, I'd use AWS Secrets Manager and rotate the password
  automatically."*
