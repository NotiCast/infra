.PHONY: setup deploy setup-pre deploy-pre deploy-terraform deploy-ansible

PYTHON_VERSION ?= python3.6
LAMBDA_FILES = lambda_function.py rds_models/*

setup: message_lambda.zip
	terraform plan -out=terraform.apply

clean:
	rm message_lambda.zip terraform.apply vendor/noticast_web/ansible/vars/terraform.json || true

message_lambda.zip:
	cd vendor/message-lambda/libs/lib/$(PYTHON_VERSION)/site-packages && \
		zip -r9 ../../../../../../message_lambda.zip *
	cd vendor/message-lambda && \
		zip -g ../../message_lambda.zip $(LAMBDA_FILES)

setup-pre:
	terraform plan -target aws_route53_zone.primary -out terraform.pre.apply pre/

deploy: deploy-terraform deploy-ansible

deploy-terraform:
	terraform apply terraform.apply

vendor/noticast_web/ansible/vars/terraform.json:
	terraform output -json > vendor/noticast_web/ansible/vars/terraform.json

deploy-ansible: vendor/noticast_web/ansible/vars/terraform.json
	ansible-playbook vendor/noticast_web/ansible/main.yml

deploy-pre:
	terraform apply terraform.pre.apply
