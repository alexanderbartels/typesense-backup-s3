#! /bin/sh

# Delete contents of Typesense data directory
# This is typically needed before restoring from a backup

set -eu
set -o pipefail

source ./env.sh

# Check if TYPESENSE_DATA_DIR is set
if [ -z "$TYPESENSE_DATA_DIR" ]; then
  echo "ERROR: TYPESENSE_DATA_DIR environment variable must be set."
  exit 1
fi

# Check if directory exists
if [ ! -d "$TYPESENSE_DATA_DIR" ]; then
  echo "Directory $TYPESENSE_DATA_DIR does not exist. Nothing to delete."
  exit 0
fi

# Check if directory is empty
if [ ! "$(ls -A "$TYPESENSE_DATA_DIR")" ]; then
  echo "Directory $TYPESENSE_DATA_DIR is already empty."
  exit 0
fi

echo "========================================"
echo "WARNING: About to delete all contents of:"
echo "$TYPESENSE_DATA_DIR"
echo "========================================"
echo ""
echo "Current contents (with last modified timestamps):"
echo ""

# List contents with timestamps
ls -lAht "$TYPESENSE_DATA_DIR"

echo ""
echo "========================================"
echo "Deleting contents..."
echo "========================================"

# Delete all contents but keep the directory
rm -rf "${TYPESENSE_DATA_DIR:?}"/*
rm -rf "${TYPESENSE_DATA_DIR:?}"/.[!.]*

echo "✓ Contents of $TYPESENSE_DATA_DIR have been deleted."
echo ""

# Verify it's empty
if [ "$(ls -A "$TYPESENSE_DATA_DIR")" ]; then
  echo "WARNING: Directory is not completely empty:"
  ls -la "$TYPESENSE_DATA_DIR"
  exit 1
else
  echo "✓ Directory is now empty and ready for restore."
fi

