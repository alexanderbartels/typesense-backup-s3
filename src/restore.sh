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
  timestamp="$1"
  key_suffix="${TYPESENSE_HOST}_${timestamp}${file_type}"
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

echo "Fetching backup from S3..."
aws $aws_args s3 cp "${s3_uri_base}/${key_suffix}" "backup${file_type}"

if [ -n "$PASSPHRASE" ]; then
  echo "Decrypting backup..."
  gpg --decrypt --batch --passphrase "$PASSPHRASE" backup.dump.gpg > backup.dump
  rm backup.dump.gpg
fi

echo "Restoring from backup to $TYPESENSE_DATA_DIR..."
tar -xzf backup.dump -C "$TYPESENSE_DATA_DIR"
rm backup.dump

echo "Restore complete."