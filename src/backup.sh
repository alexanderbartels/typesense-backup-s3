#! /bin/sh

set -eu
set -o pipefail

source ./env.sh

# It is unsafe to directly archive/backup Typesense's data directory, 
# since Typesense might have open files that it's writing to, 
# as the backup is being taken. Instead, we will use the snapshot API to create a backup.
# see https://typesense.org/docs/guide/backups.html
echo "Creating backup of $TYPESENSE_HOST database..."
curl "http://$TYPESENSE_HOST:$TYPESENSE_PORT/operations/snapshot?snapshot_path=/tmp/typesense-data-snapshot" \
  -X POST \
  -H "Content-Type: application/json" \
  -H "X-TYPESENSE-API-KEY: ${TYPESENSE_API_KEY}"

tar -czvf typesense-backup.tar.gz -C /tmp/typesense-data-snapshot .

timestamp=$(date +"%Y-%m-%dT%H:%M:%S")
s3_uri_base="s3://${S3_BUCKET}/${S3_PREFIX}/${TYPESENSE_HOST}_${timestamp}.dump"

if [ -n "$PASSPHRASE" ]; then
  echo "Encrypting backup..."
  rm -f typesense-backup.tar.gz.gpg
  gpg --symmetric --batch --passphrase "$PASSPHRASE" typesense-backup.tar.gz
  rm typesense-backup.tar.gz
  local_file="typesense-backup.tar.gz.gpg"
  s3_uri="${s3_uri_base}.gpg"
else
  local_file="typesense-backup.tar.gz"
  s3_uri="$s3_uri_base"
fi

echo "Uploading backup to $S3_BUCKET..."
aws $aws_args s3 cp "$local_file" "$s3_uri"
rm "$local_file"

echo "Backup complete."

if [ -n "$BACKUP_KEEP_DAYS" ]; then
  sec=$((86400*BACKUP_KEEP_DAYS))
  date_from_remove=$(date -d "@$(($(date +%s) - sec))" +%Y-%m-%d)
  backups_query="Contents[?LastModified<='${date_from_remove} 00:00:00'].{Key: Key}"

  echo "Removing old backups from $S3_BUCKET..."
  aws $aws_args s3api list-objects \
    --bucket "${S3_BUCKET}" \
    --prefix "${S3_PREFIX}" \
    --query "${backups_query}" \
    --output text \
    | xargs -n1 -t -I 'KEY' aws $aws_args s3 rm s3://"${S3_BUCKET}"/'KEY'
  echo "Removal complete."
fi