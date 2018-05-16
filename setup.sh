#!/bin/bash

# Don't set -eu in case policies/resources already exist
set -x

# zip up the lambda
if test ! -f message_lambda.zip; then
  pushd vendor/message-lambda
  zip -r ../../message_lambda.zip *
  popd
fi

terraform plan -out=terraform.apply
echo "Run \`terraform apply terraform.apply\` to set up infrastructure."
