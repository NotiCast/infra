#!/bin/bash

printf "Region: "
read region
printf "Messages Bucket Name: "
read bucket_name

for policy in $(ls iam/policies); do
  aws iam create-policy --policy-name "${policy%.*}" --policy-document file://iam/policies/$policy
done

for policy in $(ls iot/policies); do
  aws iot create-policy --policy-name "${policy%.*}" --policy-document file://iot/policies/$policy
done

# used by devices to know when to pull a message
# message payload format:
# `message_text:message_time:message_mp3_filename`
# use `message.split(":")` to get a list in Python
aws sns create-topic --name play-message

# write permission from the lambda to put MP3s into
# read permission from the devices to pull MP3s from
aws s3api create-bucket --bucket "$bucket_name" --region "$region" --create-bucket-configuration LocationConstraint="$region"
