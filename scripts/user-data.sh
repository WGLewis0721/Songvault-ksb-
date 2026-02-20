#!/bin/bash
# user-data.sh — bootstraps a fresh Ubuntu 22.04 EC2 instance so it runs the
# SongVault Flask application as a systemd service on port 8080.
# This script is executed once by cloud-init when the instance first boots.
# Terraform's templatefile() function replaces ${db_host}, ${db_name},
# ${db_user}, and ${db_pass} with real values before encoding the script.

set -euo pipefail

# ---------------------------------------------------------------------------
# Step 1: Update the package list and install Python 3, pip, and git.
# These are the only system-level dependencies the app needs.
# ---------------------------------------------------------------------------
apt-get update -y
apt-get install -y python3 python3-pip git

# ---------------------------------------------------------------------------
# Step 2: Create the application directory where all app files will live.
# ---------------------------------------------------------------------------
mkdir -p /opt/songvault

# ---------------------------------------------------------------------------
# Step 3: Clone the application repository from GitHub.
# Replace YOUR_GITHUB_REPO_URL with your actual repository URL before
# deploying, e.g. https://github.com/your-username/songvault-ha-webapp.git
# ---------------------------------------------------------------------------
git clone YOUR_GITHUB_REPO_URL /opt/songvault-repo

# ---------------------------------------------------------------------------
# Step 4: Copy the Flask app files into the application directory so the
# systemd service has a clean, stable working directory.
# ---------------------------------------------------------------------------
cp -r /opt/songvault-repo/app/* /opt/songvault/

# ---------------------------------------------------------------------------
# Step 5: Install Python dependencies listed in requirements.txt.
# gunicorn (the production WSGI server), Flask, and psycopg2 are installed.
# ---------------------------------------------------------------------------
pip3 install -r /opt/songvault/requirements.txt

# ---------------------------------------------------------------------------
# Step 6: Write the environment file containing database connection details.
# The systemd service reads this file so the credentials never appear in the
# service definition or process list.
# The values are injected by Terraform's templatefile() at deploy time.
# ---------------------------------------------------------------------------
cat > /etc/songvault.env <<EOF
DB_HOST=${db_host}
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASS=${db_pass}
EOF

# Restrict read permissions so only root can read the credentials.
chmod 600 /etc/songvault.env

# ---------------------------------------------------------------------------
# Step 7: Create a systemd service unit file so the app starts automatically
# on boot and restarts if it crashes.
# ---------------------------------------------------------------------------
cat > /etc/systemd/system/songvault.service <<'SERVICE'
[Unit]
Description=SongVault Flask App
After=network.target

[Service]
EnvironmentFile=/etc/songvault.env
WorkingDirectory=/opt/songvault
ExecStart=/usr/bin/gunicorn --workers 2 --bind 0.0.0.0:8080 app:app
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE

# ---------------------------------------------------------------------------
# Step 8: Reload systemd so it recognises the new service, enable it to start
# on boot, then start it immediately.
# ---------------------------------------------------------------------------
systemctl daemon-reload
systemctl enable songvault
systemctl start songvault
