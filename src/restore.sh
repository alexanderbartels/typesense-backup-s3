#! /bin/sh

# Restore a Typesense backup from S3
# see: https://typesense.org/docs/guide/backups.html#restore-steps

set -u # `-e` omitted intentionally, but i can't remember why exactly :'(
set -o pipefail

source ./env.sh

# Check if TYPESENSE_DATA_DIR is set
if [ -z "$TYPESENSE_DATA_DIR" ]; then
  echo "ERROR: TYPESENSE_DATA_DIR environment variable must be set."
  exit 1
fi

# Check if the data directory is empty
if [ -d "$TYPESENSE_DATA_DIR" ] && [ "$(ls -A "$TYPESENSE_DATA_DIR")" ]; then
  echo "ERROR: The directory $TYPESENSE_DATA_DIR is not empty."
  echo "Restore process aborted to prevent data loss."
  echo "Please ensure the directory is empty before restoring."
  exit 1
fi

s3_uri_base="s3://${S3_BUCKET}/${S3_PREFIX}"

if [ -z "$PASSPHRASE" ]; then
  file_type=".dump"
else
  file_type=".dump.gpg"
fi

if [ $# -eq 1 ]; then
  backup_arg="$1"
  
  # Check if argument is a full filename (contains the host and ends with extension)
  if echo "$backup_arg" | grep -q "\.dump"; then
    # It's a full filename, use as is
    key_suffix="$backup_arg"
  elif echo "$backup_arg" | grep -q "^${TYPESENSE_HOST}_"; then
    # It's a filename without extension (host_timestamp)
    key_suffix="${backup_arg}${file_type}"
  else
    # It's just a timestamp, prepend the host
    key_suffix="${TYPESENSE_HOST}_${backup_arg}${file_type}"
  fi
else
  echo "Finding latest backup..."
  key_suffix=$(
    aws $aws_args s3 ls "${s3_uri_base}/" \
      | grep "${TYPESENSE_HOST}_" \
      | sort \
      | tail -n 1 \
      | awk '{ print $4 }'
  )
  
  if [ -z "$key_suffix" ]; then
    echo "ERROR: No backup found for ${TYPESENSE_HOST} in ${s3_uri_base}"
    exit 1
  fi
fi

echo "Using backup file: ${key_suffix}"
echo "Full S3 path: ${s3_uri_base}/${key_suffix}"

# Check if the backup exists in S3 before attempting to download
echo "Checking if backup exists in S3..."
if ! aws $aws_args s3 ls "${s3_uri_base}/${key_suffix}" > /dev/null 2>&1; then
  echo "ERROR: Backup file not found in S3: ${s3_uri_base}/${key_suffix}"
  echo ""
  echo "Available backups for ${TYPESENSE_HOST}:"
  aws $aws_args s3 ls "${s3_uri_base}/" | grep "${TYPESENSE_HOST}_" || echo "  (none found)"
  exit 1
fi

echo "Fetching backup from S3..."
if ! aws $aws_args s3 cp "${s3_uri_base}/${key_suffix}" "backup${file_type}"; then
  echo "ERROR: Failed to download backup from S3"
  exit 1
fi

if [ -n "$PASSPHRASE" ]; then
  echo "Decrypting backup..."
  gpg --decrypt --batch --passphrase "$PASSPHRASE" backup.dump.gpg > backup.dump
  rm backup.dump.gpg
fi

echo "Restoring from backup to $TYPESENSE_DATA_DIR..."
tar -xzf backup.dump -C "$TYPESENSE_DATA_DIR"
rm backup.dump

echo "Restore complete."