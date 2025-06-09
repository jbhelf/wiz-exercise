#!/usr/bin/env bash
set -euo pipefail

TIMESTAMP=$(date +%Y-%m-%dT%H%M%S)
DB_HOST="${MONGO_HOST:-mongo.default.svc.cluster.local}"
DB_NAME="${MONGO_DB:-taskydb}"
BUCKET="wizex-mongo-backups"
FILENAME="backup-${DB_NAME}-${TIMESTAMP}.gz"

# dump and gzip
mongodump --host "$DB_HOST" --db "$DB_NAME" \
  --archive="/tmp/${FILENAME}" --gzip

# upload and make public-read
aws s3 cp "/tmp/${FILENAME}" "s3://${BUCKET}/${FILENAME}" \
  --acl public-read