.PHONY: setup deploy setup-pre deploy-pre deploy-terraform deploy-ansible \
	fullclean clean

PYTHON_VERSION ?= python3.6
LAMBDA_FILES = lambda_function.py rds_models/*
ANSIBLE_JSON_FILE = vendor/noticast_web/ansible/vars/terraform.json
NOTICAST_WEB_VERSION = v0.1.2

setup: message_lambda.zip
	terraform plan -out=terraform.apply

fullclean: clean
	rm message_lambda.zip

clean:
	rm terraform.apply hosts $(ANSIBLE_JSON_FILE) || true

message_lambda.zip:
	$(MAKE) -C vendor/message-lambda
	cd vendor/message-lambda/libs/lib/$(PYTHON_VERSION)/site-packages && \
		zip -r9 ../../../../../../message_lambda.zip *
	cd vendor/message-lambda && \
		zip -g ../../message_lambda.zip $(LAMBDA_FILES)

setup-pre:
	terraform plan -target aws_route53_zone.primary -out \
		terraform.pre.apply pre/

deploy: deploy-terraform deploy-ansible

deploy-terraform:
	terraform apply terraform.apply

$(ANSIBLE_JSON_FILE):
	mkdir -p $(dir $(ANSIBLE_JSON_FILE))
	terraform output -json > $(ANSIBLE_JSON_FILE)

hosts: $(ANSIBLE_JSON_FILE)
	echo '[prod]' > hosts
	jq -r '.noticast_ips.value[]' < $(ANSIBLE_JSON_FILE) >> hosts
	echo >> hosts
	echo '[prod:vars]' >> hosts
	echo noticast_web_version=$(NOTICAST_WEB_VERSION) >> hosts
	echo >> hosts
	echo '[dev]' >> hosts
	jq -r '.noticast_ips_dev.value[]' < $(ANSIBLE_JSON_FILE) >> hosts
	echo >> hosts
	echo '[dev:vars]' >> hosts
	echo noticast_web_version=master >> hosts

deploy-ansible: $(ANSIBLE_JSON_FILE) hosts
	ansible-playbook vendor/noticast_web/ansible/main.yml -f 15

deploy-pre:
	terraform apply terraform.pre.apply
