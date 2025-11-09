if [ -z "$S3_BUCKET" ]; then
  echo "You need to set the S3_BUCKET environment variable."
  exit 1
fi

if [ -z "$TYPESENSE_HOST" ]; then
  echo "You need to set the TYPESENSE_HOST environment variable."
  exit 1
fi

if [ -z "$TYPESENSE_PORT" ]; then
  echo "You need to set the TYPESENSE_PORT environment variable."
  exit 1
fi

if [ -z "$TYPESENSE_API_KEY" ]; then
  echo "You need to set the TYPESENSE_API_KEY environment variable."
  exit 1
fi

if [ -z "$S3_ENDPOINT" ]; then
  aws_args=""
else
  aws_args="--endpoint-url $S3_ENDPOINT"
fi


if [ -n "$S3_ACCESS_KEY_ID" ]; then
  export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
fi
if [ -n "$S3_SECRET_ACCESS_KEY" ]; then
  export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
fi
export AWS_DEFAULT_REGION=$S3_REGION
