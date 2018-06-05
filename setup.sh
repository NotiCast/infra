#!/bin/bash

# Don't set -eu in case policies/resources already exist
set -x

case "$1" in
  --pre)
    # Set up domain name
    terraform plan -target=aws_route53_zone.primary -out terraform.pre.apply pre/
    echo "Run \`terraform apply terraform.pre.apply\` to configure DNS."
    break
    ;;
  *)
    # zip up the lambda
    if test ! -f message_lambda.zip; then
      pushd vendor/message-lambda
      zip -r ../../message_lambda.zip *
      popd
    fi

    terraform plan -out=terraform.apply
    echo "Run \`terraform apply terraform.apply\` to set up infrastructure."
    break
    ;;
esac
