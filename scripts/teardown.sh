#!/usr/bin/env bash
set -euo pipefail

echo ""
echo "WARNING: This will delete everything. Your app, your database, your data."
echo "You can rebuild it anytime by running terraform apply. It takes about 10 minutes."
echo ""

read -rp "Type YES (all caps) to confirm: " answer

if [ "$answer" != "YES" ]; then
  echo "Cancelled. Nothing was deleted."
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../terraform"

if ! terraform destroy -auto-approve; then
  echo ""
  echo "ERROR: terraform destroy failed. Some resources may not have been deleted."
  echo "Check the AWS Console and run the script again."
  exit 1
fi

TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S %Z")

echo ""
echo "Done. Everything has been deleted. Your AWS bill stops now."
echo "Completed at: $TIMESTAMP"
echo ""
echo "To rebuild anytime: cd terraform && terraform apply"
